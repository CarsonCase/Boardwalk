// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IOracle{
    function priceOf(address) external view returns(int,uint8);
}

interface mIERC20 is IERC20{
    function mint(address,uint) external;
}

contract TestDex{
    address weth;
    address stablecoin;
    IOracle oracle;

    constructor(address _oracle, address _stablecoin){
        oracle = IOracle(_oracle);
        stablecoin = _stablecoin;
        weth = address(new ERC20("WETH", "Test WETH"));
    }

    function WETH() external view returns(address){
        return weth;
    }

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts){
        amounts = new uint[](path.length);
        if(path[0] == weth){
            amounts[0] = amountIn;
            amounts[1] = uint(_getPriceUnderlyingUSD(amountIn));
        }else{
            amounts[0] = amountIn;
            amounts[1] = uint(_getAmountOfUnderlyingForUSD(int(amountIn)));
        }
    }


    function swapExactETHForTokens(
        uint amountOutMin, 
        address[] calldata path, 
        address to, 
        uint deadline
        )
        external
        payable
        returns (uint[] memory amounts)
    {
        require(path[0] == weth, "must swap WETH");
        require(path[1] == stablecoin, "Must be swapping to stablecoin");
        require(msg.value > 0, "Cannot swap 0");
        IERC20(path[1]).transfer(to, uint(_getPriceUnderlyingUSD(msg.value)));
        amounts = new uint[](path.length);
        amounts[0] = msg.value;
        amounts[1] = msg.value;
    }

    function swapExactTokensForETH(
        uint amountIn, 
        uint amountOutMin, 
        address[] calldata path, 
        address to, 
        uint deadline
        )
        external
        returns (uint[] memory amounts)
    {
        require(path[1] == weth, "must be swapping to WETH");
        require(path[0] == stablecoin, "Must swap stablecoin");
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        payable(msg.sender).transfer(uint(_getAmountOfUnderlyingForUSD(int(amountIn))));
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        amounts[1] = amountIn;
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity){
        IERC20(token).transferFrom(msg.sender, address(this),amountTokenDesired);
    }


    function _getPriceUnderlyingUSD(uint _underlyingAm) public view returns(int){
        (int price, uint8 decimals) = oracle.priceOf(weth);
        return((int(_underlyingAm) * price) / int(10**decimals));
    }

    function _getAmountOfUnderlyingForUSD(int _amount) public view returns(int){
        (int price, uint8 decimals) = oracle.priceOf(weth);
        return((int(10**decimals) * (int(_amount)) / price));
    }


}