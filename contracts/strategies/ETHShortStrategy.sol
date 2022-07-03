// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "./StrategyStandard.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";
/**
* @title ETHShortStrategy
* @author Caron Case (carsonpcase@gmail.com)
    contract to short ETH and 
*/
contract ETHShortStrategy is StrategyStandard{

    IPool public AavePool;

    uint public debtInvested;

    address public eth;

    IUniswapV2Router02 public dex;
    uint constant secondsInYear = 31540000;

    int96 apr = 12;

    uint constant SLIPPAGE = 5;                     // making this owner controlled is not a bad idea

    constructor(IPool _aavePool, address _swaps, address _treasury, address _dex) StrategyStandard(_treasury){
        AavePool = _aavePool;
        swaps = ISwaps(_swaps);
        dex = IUniswapV2Router02(_dex);
        IERC20(stablecoin).approve(_dex,2**256-1);
        transferOwnership(_treasury);
        eth = dex.WETH();
    }

    receive() payable external{

    }

    /// @dev 10 out of 100 (ONE_HUNDRED_PERCENT)
    function minColatearl() external pure override returns(uint){
        return 10;
    }

    /// todo for the next 4 functions. Replace swapping to ETH with:
    /// depositing in Aave
    /// borrowing ETH (add debt obligation to struct)
    /// selling the ETH
    /// those coins (added to struct with debt) is the "underlying" bet on
    function fund(uint256 _amountInvestment) public override onlyOwner{
        require(_amountInvestment != 0, "Cannot fund with 0");
        IERC20(stablecoin).transferFrom(treasury, address(this), _amountInvestment);
        IERC20(stablecoin).approve(address(AavePool), _amountInvestment);
        AavePool.supply(address(stablecoin), _amountInvestment, address(this), 0);
        (DataTypes.ReserveData memory reserveData) = AavePool.getReserveData(address(eth));
        (,,uint256 availableBorrowsBase,,,) = AavePool.getUserAccountData(address(this));
        uint toBorrow = (availableBorrowsBase * 75)/ 100;

        uint stableBalBefore = IERC20(stablecoin).balanceOf(address(this));
        uint debtBefore = IERC20(reserveData.variableDebtTokenAddress).balanceOf(address(this));

        // 2 = variable inte)rest rate model, 1 = stable
        AavePool.borrow(eth, toBorrow, 2, 0, address(this));

        address[] memory path = new address[](2);
        path[0] = eth;
        path[1] = stablecoin;

        uint minOut = _getMinOut(_amountInvestment, path);
        dex.swapExactETHForTokens{value: toBorrow}(minOut,path,address(this),block.timestamp + 30);

        // increase underlying invested by the amount of stables added
        uint stableBalAfter = IERC20(stablecoin).balanceOf(address(this));
        underlyingInvested += (stableBalAfter - stableBalBefore);
        debtInvested += IERC20(reserveData.variableDebtTokenAddress).balanceOf(address(this)) - debtBefore;
    }

    function removeFunds(uint256 _amountToRemove, address _receiver) public override onlyOwner{
        require(_amountToRemove <= address(this).balance, "Not enough eth in strategy");
        super.removeFunds(_amountToRemove, _receiver);

        address[] memory path = new address[](2);
        path[0] = eth;
        path[1] = stablecoin;

        uint minOut = _getMinOut(_amountToRemove, path);
        dex.swapExactETHForTokens{value: _amountToRemove}(minOut, path, _receiver, block.timestamp + 30);
    }

    function getPriceUnderlyingStable(uint _underlyingAm) public view override returns(int){
        require(_underlyingAm > 0, "Looking for price of negative underlying amount");
        address[] memory path = new address[](2);
        path[0] = eth;
        path[1] = stablecoin;
        uint[] memory amountsOut = dex.getAmountsOut(_underlyingAm, path);
        return(int(amountsOut[1]));
    }

    function getAmountOfUnderlyingForStable(int _amount) public view override returns(int){
        require(_amount > 0, "Looking for price of negative stablecoin amount");
        address[] memory path = new address[](2);
        path[0] = stablecoin;
        path[1] = eth;
        uint[] memory amountsOut = dex.getAmountsOut(uint(_amount), path);
        return(int(amountsOut[1]));
    }

    function getFlowRate(uint _amountUnderlying) public view returns(int96){
        return (int96(getPriceUnderlyingStable(_amountUnderlying/secondsInYear)) * apr) / 100;
    }

    /**
    * @dev override just handles swaps logic. Verifying underlying available is done in parent
     */
    function _issueSwap(address _issueTo, uint _amountUnderlying) internal override{
        swaps.newSwap(treasury,_issueTo, getFlowRate(_amountUnderlying),_amountUnderlying);
    }

    function _getMinOut(uint _amountIn, address[] memory _path) internal view returns(uint minOut){
        uint out = dex.getAmountsOut(_amountIn, _path)[_path.length-1];
        minOut = (out * (ONE_HUNDRED_PERCENT - SLIPPAGE)) / ONE_HUNDRED_PERCENT;
    }


}