// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "./StrategyStandard.sol";
import "../interfaces/IUniswapV2Router02.sol";

interface ISwaps{
    function newSwap(address _receiver, address _payer, int96 _requiredFlowRate, uint _amountUnderlying) external;
}
/**
* @title ETHHODLStrategy
* @author Caron Case (carsonpcase@gmail.com)
    contract to standardize what strategies do 
*/
contract ETHHODLStrategy is StrategyStandard{
    // for testing
    address public eth = address(bytes20(keccak256("ETH")));

    IUniswapV2Router02 public immutable dex;
    uint constant secondsInYear = 31540000;

    int priceUSD = 2;
    int96 apr = 12;
    ISwaps public swaps;
    constructor(address _swaps, address _treasury, address _oracle, address _dex) StrategyStandard(_treasury, _oracle){
        swaps = ISwaps(_swaps);
        dex = IUniswapV2Router02(_dex);
        IERC20(stablecoin).approve(_dex,2**256-1);
        transferOwnership(_treasury);
    }

    receive() payable external{

    }

    // TEST only
    function updatePriceE18(int _new) external{
        priceUSD = _new;
    }

    function fund(uint256 _amountInvestment) public override onlyOwner{
        super.fund(_amountInvestment);
        address[] memory path = new address[](2);
        path[0] = stablecoin;
        path[1] = dex.WETH();

        dex.swapExactTokensForETH(_amountInvestment,0,path,address(this),block.timestamp + 30);
    }

    function removeFunds(uint256 _amountToRemove) public override onlyOwner{
        super.removeFunds(_amountToRemove);

        address[] memory path = new address[](2);
        path[0] = dex.WETH();
        path[1] = stablecoin;

        dex.swapExactETHForTokens{value: _amountToRemove}(0, path, treasury, block.timestamp + 30);
    }

    function getPriceUnderlyingUSD(uint _underlyingAm) public view override returns(int){
        (int price, uint8 decimals) = oracle.priceOf(eth);
        return((int(_underlyingAm) * price) / int(10**decimals));
    }

    function getFlowRate(uint _amountUnderlying) public view returns(int96){
        return (int96(getPriceUnderlyingUSD(_amountUnderlying/secondsInYear)) * apr) / 100;
    }

    /**
    * @dev override just handles swaps logic. Verifying underlying available is done in parent
     */
    function _issueSwap(address _issueTo, uint _amountUnderlying) internal override{
        swaps.newSwap(treasury,_issueTo, getFlowRate(_amountUnderlying),_amountUnderlying);
    }


}