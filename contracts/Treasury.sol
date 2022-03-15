// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ISwapReceiver.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IUniswapV2Router02.sol";

interface IGovToken is IERC20{
    function mint(address,uint) external;
}

/**
* @title Treasury
* @author Caron Case (carsonpcase@gmail.com)
    Treasury is to be governed by the governance time lock and thus that is the owner
 */
contract Treasury is Ownable, ISwapReceiver {
    IERC20 public stablecoin;
    IGovToken public nativeToken;
    IUniswapV2Router02 public dex;

    address public swaps;
    uint256 public totalOwedCollateral;
    mapping(address => uint256) public availableCollateral;
    mapping(address => uint256) public strategiesApprovedBalances;

    constructor(address _stableCoin, address _nativeToken, address _swaps) Ownable(){
        stablecoin = IERC20(_stableCoin);
        nativeToken = IGovToken(_nativeToken);
        dex = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        stablecoin.approve(address(dex),2**256 - 1);
        nativeToken.approve(address(dex),2**256 - 1);
        swaps = _swaps;
    }

    event NewSettlement(int amount);

    function addCollateral(uint256 _amount) external{
        stablecoin.transferFrom(msg.sender, address(this), _amount);
        _addCollateralForUser(msg.sender, _amount);
    }

    function transferFundsToStrategy(address _strategy, uint _amount) external onlyOwner{
        require(_amount <= getBalance(), "Can not deposit more than the available balance of the treasury");
        stablecoin.approve(_strategy,_amount);
        IStrategy(_strategy).fund(_amount);
        strategiesApprovedBalances[_strategy] = 2**256-1;        // give strategies full access for now
    }

    function issueShares(uint256 _amount) external onlyOwner{
        nativeToken.mint(address(this), _amount);

        address[] memory path = new address[](2);
        path[0] = address(nativeToken);
        path[1] = address(stablecoin);

        /// todo add slippage
        dex.swapExactTokensForTokens(_amount, 0, path, address(this), block.timestamp + 30);

    }


    function verifyNewSwap(address _swapCreator, uint _amountUnderlying) external view override returns(bool){
        return(strategiesApprovedBalances[_swapCreator] >= _amountUnderlying);
    }

    uint public Test;
    function settle(int _usdSettlement, uint _collateralToFree, address _recipient, address _strategy) override external{
        require(msg.sender == swaps,"Only the swaps contract can call this");
        _addCollateralForUser(_recipient, _collateralToFree);
        if(_usdSettlement == 0){return;}
        if(_usdSettlement > 0){
            if(int(getBalance()) >= _usdSettlement){
                stablecoin.transfer(_recipient, uint(_usdSettlement));
            }else{
                uint toSwap = uint(IStrategy(_strategy).getAmountOfUnderlyingForUSD(_usdSettlement));
                        Test = toSwap;

                IStrategy(_strategy).removeFunds(toSwap, _recipient);
            }
        }else{
            _removeCollateralForUser(_recipient, uint256(_usdSettlement * -1));
        }
        emit NewSettlement(_usdSettlement);
    }

    function getAvailableCollateral(address _of) external view override returns(uint){
        return(availableCollateral[_of]);
    }

    function lockCollateral(address _of, uint _amount) external override{
        require(_amount <= availableCollateral[_of], "User does not have enough collateral to lock");
        _removeCollateralForUser(_of, _amount);
    }

    function getBalance() public view returns (uint256 balance){
        balance = stablecoin.balanceOf(address(this)) - totalOwedCollateral;
    }

    function _addCollateralForUser(address _user, uint256 _toChange) private{
        totalOwedCollateral += _toChange;
        availableCollateral[_user] += _toChange;
    }

    function _removeCollateralForUser(address _user, uint256 _toChange) private{
        totalOwedCollateral = 
        _toChange >= totalOwedCollateral ?
            0:
            totalOwedCollateral - _toChange;


        availableCollateral[_user] = 
        _toChange >= availableCollateral[_user] ?
            0:
            availableCollateral[_user] - _toChange;
    }

}
