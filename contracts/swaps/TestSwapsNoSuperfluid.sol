// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/ISwapReceiver.sol";
import "../interfaces/IStrategy.sol";

contract TestSwapsNoSuperfluid is ERC721, Ownable{

    uint public index = 0;

    IERC20 public token;
    mapping(bytes32 => uint) public flowIDToReceiverNFT;

    struct asset{
        int96 flowRateForAssets;
        uint amountUnderlyingExposed;
        uint lockedCollateral;
        int priceUSD;
        address oracle;
    }

    mapping(uint => asset) public receiverAssetsOwed;

    constructor(address _token) Ownable() ERC721("Total Return Swap", "TRS"){
        token = IERC20(_token);
    }

    event Error(string message);
    event CaughtTermination(bytes32 _id, int96 _flowTerminated);

    event NewSwap(address _receiver, address _payer);

    /// @dev to be called by strategies. Anyone can make swaps. But it's the strategies that have the assets
    function newSwap(address _receiver, address _payer, int96 _requiredFlowRate, uint _amountUnderlying) external{
        require(ISwapReceiver(_receiver).verifyNewSwap(msg.sender,_amountUnderlying), "This receiver did not permit you to issue this swap");
        bytes32 fid = _generateFlowId(_payer, address(this));
        flowIDToReceiverNFT[fid] = index;
        ISwapReceiver(_receiver).lockCollateral(_payer, _getRequiredCollateral(_amountUnderlying));

        // mint NFTs
        _mintReceiver(_receiver,_amountUnderlying, 0, msg.sender);    // note receiver will always have an even ID 0,2,4,ect.
        _mintPayer(_payer);                                                         // note payer will always have an odd ID 1,3,5,ect.
        emit NewSwap(_receiver, _payer);
    }

    function afterAgreementTerminated(
        bytes32 _agreementId
    )
        external
    {

        // get the resulting flow reduction to receiver and adjust our flow
        uint receiverIndex = flowIDToReceiverNFT[_agreementId];
        address receiver = ownerOf(receiverIndex);
        asset storage a = receiverAssetsOwed[receiverIndex];

        // and also lookup the settlement amount and trigger that in receiver
        int settlement = IStrategy(a.oracle).getPriceUnderlyingUSD(a.amountUnderlyingExposed) - a.priceUSD;
        
        // payer index is always +1 receiver
        ISwapReceiver(receiver).settle(settlement, a.lockedCollateral, ownerOf(receiverIndex+1));

        _burn(receiverIndex);
        _burn(receiverIndex+1);
    }


    function _mintReceiver(address _receiver, uint _amountUnderlying, int96 _flowRate, address _oracle) internal{
        _mint(_receiver,index); 
        int usdVal = IStrategy(_oracle).getPriceUnderlyingUSD(_amountUnderlying);
        asset memory a =asset(_flowRate, _amountUnderlying, _getRequiredCollateral(_amountUnderlying), usdVal, _oracle);
        _updateReceiverAssetsOwed(index,a);         
        index++;
 
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

    function _getRequiredCollateral(uint _amountUnderlying) internal pure returns(uint){
        return((_amountUnderlying) / 10);
    }
}