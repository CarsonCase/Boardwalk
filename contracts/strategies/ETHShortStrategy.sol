// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "./StrategyStandard.sol";
import "../interfaces/IUniswapV2Router02.sol";


/**
* @title ETHShortStrategy
* @author Caron Case (carsonpcase@gmail.com)
    contract to short ETH and 
*/
contract ETHShortStrategy is StrategyStandard{

    address public eth;

    IUniswapV2Router02 public dex;
    uint constant secondsInYear = 31540000;

    int96 apr = 12;

    uint constant SLIPPAGE = 5;                     // making this owner controlled is not a bad idea

    constructor(address _swaps, address _treasury, address _dex) StrategyStandard(_treasury){
        swaps = ISwaps(_swaps);
        dex = IUniswapV2Router02(_dex);
        IERC20(stablecoin).approve(_dex,2**256-1);
        transferOwnership(_treasury);
        eth = dex.WETH();
    }

}