// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// initializing the CFA Library
import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {
    SuperAppBase
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    ContextDefinitions,
    SuperAppDefinitions
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import "../interfaces/ISwapReceiver.sol";
import "../interfaces/IStrategy.sol";

contract Swaps is ERC721, Ownable, SuperAppBase{

    uint public index = 0;

    ISuperfluid private _host; // host
    IConstantFlowAgreementV1 private _cfa; // the stored constant flow agreement class address

    ISuperToken public token;
    mapping(bytes32 => uint) public flowIDToReceiverNFT;

    struct asset{
        int96 flowRateForAssets;
        uint amountUnderlyingExposed;
        int priceUSD;
        address oracle;
    }

    mapping(uint => asset) public receiverAssetsOwed;

    constructor(ISuperfluid host, IConstantFlowAgreementV1 cfa, address _token) Ownable() ERC721("Total Return Swap", "TRS"){
        _host = host;
        _cfa = cfa;
        token = ISuperToken(_token);

        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP |
            SuperAppDefinitions.AFTER_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.AFTER_AGREEMENT_UPDATED_NOOP;

        _host.registerApp(configWord);
    }

    event Error(string message);
    event CaughtTermination(bytes32 _id, int96 _flowTerminated);

    modifier onlyHost() {
        require(msg.sender == address(_host), "RedirectAll: support only one host");
        _;
    }

    event NewSwap(address _receiver, address _payer);

    /// @dev to be called by strategies. Anyone can make swaps. But it's the strategies that have the assets
    function newSwap(address _receiver, address _payer, int96 _requiredFlowRate, uint _amountUnderlying) external{
        (, int96 initialFlowRate,,) = _cfa.getFlow(token, _payer,address(this));
        require(ISwapReceiver(_receiver).verifyNewSwap(msg.sender,_amountUnderlying), "This receiver did not permit you to issue this swap");
        require(initialFlowRate >= _requiredFlowRate, 
            "Not paying enough to initialize this swap");

        bytes32 fid = _generateFlowId(_payer, address(this));
        flowIDToReceiverNFT[fid] = index;

        // since funds are coming here, redirect the same amount out to the actual receiver
        _newFlow(_receiver, initialFlowRate);
        // mint NFTs
        _mintReceiver(_receiver,_amountUnderlying, initialFlowRate, msg.sender);    // note receiver will always have an even ID 0,2,4,ect.
        _mintPayer(_payer);                                                         // note payer will always have an odd ID 1,3,5,ect.
        emit NewSwap(_receiver, _payer);
    }

    function afterAgreementTerminated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32 _agreementId,
        bytes calldata /*_agreementData*/,
        bytes calldata ,//_cbdata,
        bytes calldata _ctx
    )
        external
        override
        onlyHost
        returns (bytes memory newCtx)
    {
        // error handling
        if (_superToken != token || !_isCFAv1(_agreementClass)) return _ctx;

        // get the resulting flow reduction to receiver and adjust our flow
        uint receiverIndex = flowIDToReceiverNFT[_agreementId];
        address receiver = ownerOf(receiverIndex);
        asset storage a = receiverAssetsOwed[receiverIndex];
        int96 flowCancelled = a.flowRateForAssets;
        (, int96 initialFlowRate,,) = _cfa.getFlow(token, address(this),receiver);
        int96 newFlow = initialFlowRate - flowCancelled;
        if(newFlow <= 0){
            emit Error("After agreement terminated. New flow is less than  or = 0");
        }else{
            a.flowRateForAssets = 0;
            _newFlow(receiver, newFlow);
        }

        // and also lookup the settlement amount and trigger that in receiver
        int settlement = IStrategy(a.oracle).getPriceUnderlyingUSD(a.amountUnderlyingExposed) - a.priceUSD;
        
        // payer index is always +1 receiver
        ISwapReceiver(receiver).settle(settlement, ownerOf(receiverIndex+1));

        emit CaughtTermination(_agreementId, flowCancelled);
        _burn(receiverIndex);
        _burn(receiverIndex+1);
        return _ctx;
    }

    function emergencySettle(bytes32 _agreementId) external{
        // get the resulting flow reduction to receiver and adjust our flow
        uint receiverIndex = flowIDToReceiverNFT[_agreementId];
        address receiver = ownerOf(receiverIndex);
        asset storage a = receiverAssetsOwed[receiverIndex];
        int96 flowCancelled = a.flowRateForAssets;
        (, int96 initialFlowRate,,) = _cfa.getFlow(token, address(this),receiver);
        int96 newFlow = initialFlowRate - flowCancelled;
        if(newFlow <= 0){
            emit Error("After agreement terminated. New flow is less than  or = 0");
        }else{
            a.flowRateForAssets = 0;
            _newFlow(receiver, newFlow);
        }

        // and also lookup the settlement amount and trigger that in receiver
        int settlement = IStrategy(a.oracle).getPriceUnderlyingUSD(a.amountUnderlyingExposed) - a.priceUSD;
        
        // payer index is always +1 receiver
        ISwapReceiver(receiver).settle(settlement, ownerOf(receiverIndex+1));

        _burn(receiverIndex);
        _burn(receiverIndex+1);

    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType()
            == keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    }

    function _mintReceiver(address _receiver, uint _amountUnderlying, int96 _flowRate, address _oracle) internal{
        _mint(_receiver,index); 
        int usdVal = IStrategy(_oracle).getPriceUnderlyingUSD(_amountUnderlying);
        asset memory a =asset(_flowRate, _amountUnderlying, usdVal, _oracle);
        _updateReceiverAssetsOwed(index,a);         
        index++;
 
    }

    function _newFlow(address newReceiver, int96 _flowRate) internal{
        (,int96 outFlowRate,,) = _cfa.getFlow(token, address(this), newReceiver);
        // if no flow rate delete
        if(_flowRate == 0){
            _host.callAgreement(
                _cfa,
                abi.encodeWithSelector(
                    _cfa.deleteFlow.selector,
                    token,
                    address(this),
                    newReceiver,
                    new bytes(0)
                ),
                "0x"
            );
            return;
        }
        // if no flow to this receiver yet start one
        if(outFlowRate == 0){
            _host.callAgreement(
                _cfa,
                abi.encodeWithSelector(
                    _cfa.createFlow.selector,
                    token,
                    newReceiver,
                    _flowRate,
                    new bytes(0)
                ),
                "0x"
            );
        // else update with new flow
        }else{
            _host.callAgreement(
                _cfa,
                abi.encodeWithSelector(
                    _cfa.updateFlow.selector,
                    token,
                    newReceiver,
                    _flowRate,
                    new bytes(0)
                ),
                "0x"
            );
        }

    }
    
    // @dev Change the Receiver of the total flow
    function _changeReceiver(address oldReceiver, address newReceiver, int96 _flowRate) internal {
        require(newReceiver != address(0), "New receiver is zero address");
        // @dev because our app is registered as final, we can't take downstream apps
        require(!_host.isApp(ISuperApp(newReceiver)), "New receiver can not be a superApp");
        if (newReceiver == oldReceiver) return ;
        // @dev delete flow to old receiver
        (,int96 outFlowRate,,) = _cfa.getFlow(token, address(this), oldReceiver); //CHECK: unclear what happens if flow doesn't exist.
        if(outFlowRate > 0){
          _host.callAgreement(
              _cfa,
              abi.encodeWithSelector(
                  _cfa.deleteFlow.selector,
                  token,
                  address(this),
                  oldReceiver,
                  new bytes(0)
              ),
              "0x"
          );
          // @dev create flow to new receiver
          _host.callAgreement(
              _cfa,
              abi.encodeWithSelector(
                  _cfa.createFlow.selector,
                  token,
                  newReceiver,
                  _flowRate,
                  new bytes(0)
              ),
              "0x"
          );
        }

    }

    function _mintPayer(address _payer) internal{
        _mint(_payer,index); 
        index++;
    }

    function _updateReceiverAssetsOwed(uint _index, asset memory a) internal{
        require(_index % 2 == 0, "Can only updated assets owed for receivers");
        receiverAssetsOwed[_index] = a;
    }

    function _generateFlowId(address sender, address receiver) public pure returns(bytes32 id) {
        return keccak256(abi.encode(sender, receiver));
    }
}