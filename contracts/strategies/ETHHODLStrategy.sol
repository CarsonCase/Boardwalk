// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "./StrategyStandard.sol";
import "../interfaces/IUniswapV2Router02.sol";


/**
* @title ETHHODLStrategy
* @author Caron Case (carsonpcase@gmail.com)
    contract to standardize what strategies do 
*/
contract ETHHODLStrategy is StrategyStandard{
    // for testing
    uint public priceMultiplier = 1;

    address public eth;

    IUniswapV2Router02 public dex;
    uint constant secondsInYear = 31540000;

    int96 apr = 12;

    uint constant SLIPPAGE = 5;                     // making this owner controlled is not a bad idea
    
    /// @dev THIS IS FOR TESTING ONLY
    function changeMultiplier(uint _new) external{
        priceMultiplier = _new;
    }

    constructor(address _swaps, address _treasury, address _dex) StrategyStandard(_treasury){
        swaps = ISwaps(_swaps);
        dex = IUniswapV2Router02(_dex);
        IERC20(stablecoin).approve(_dex,2**256-1);
        transferOwnership(_treasury);
        eth = dex.WETH();
    }

    receive() payable external{

    }

    /// @dev 10 out of 100 (ONE_HUNDRED_PERCENT)
    function minColatearl() external view override returns(uint){
        return 10;
    }


    function fund(uint256 _amountInvestment) public override onlyOwner{
        IERC20(stablecoin).transferFrom(treasury, address(this), _amountInvestment);
        address[] memory path = new address[](2);
        path[0] = stablecoin;
        path[1] = eth;

        uint minOut = _getMinOut(_amountInvestment, path);
        uint balBefore = address(this).balance;
        dex.swapExactTokensForETH(_amountInvestment,minOut,path,address(this),block.timestamp + 30);

        // increase underlying invested by the amount of ETH added
        underlyingInvested += (address(this).balance - balBefore);
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
        return(int(priceMultiplier * amountsOut[1]));
    }

    function getAmountOfUnderlyingForStable(int _amount) public view override returns(int){
        require(_amount > 0, "Looking for price of negative stablecoin amount");
        address[] memory path = new address[](2);
        path[0] = stablecoin;
        path[1] = eth;
        uint[] memory amountsOut = dex.getAmountsOut(uint(_amount), path);
        return(int(priceMultiplier * amountsOut[1]));
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

    /**
    * todo: Make this not dumb. Needs to actually use the router to find the price of the token...
     */
    function _getMinOut(uint _amountIn, address[] memory _path) internal view returns(uint minOut){
        uint out = dex.getAmountsOut(_amountIn, _path)[_path.length-1];
        minOut = (out * (ONE_HUNDRED_PERCENT - SLIPPAGE)) / ONE_HUNDRED_PERCENT;
    }


}