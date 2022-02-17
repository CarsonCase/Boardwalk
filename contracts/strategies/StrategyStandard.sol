// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITreasury{
    function stablecoin() external returns(IERC20);
}

interface IOracle{
    function getPriceOf(address) external view returns(int,uint8);
}

/**
* @title StrategyStandard
* @author Caron Case (carsonpcase@gmail.com)
    contract to standardize what strategies do 
*/
abstract contract StrategyStandard is Ownable{
    address public immutable treasury;
    address internal stablecoin;
    uint256 public underlyingInvested;
    uint256 public underlyingExposedToSwaps;
    IOracle public oracle;

    constructor(address _treasury, address _oracle) Ownable(){
        treasury = _treasury;
        stablecoin = address(ITreasury(_treasury).stablecoin());
        oracle = IOracle(_oracle);
    }

    function getPriceUnderlyingUSD(uint _underlyingAm) external virtual returns(int){
        (int price, uint8 decimals) = oracle.getPriceOf(stablecoin);
        return((int(_underlyingAm) * price) / int(10**decimals));
    }

    /**
    * @dev fund function to provide funds to the strategy
    * override to provide with the actual logic of the investment strategy
     */
    function fund(uint256 _amountInvestment) public virtual onlyOwner{
        underlyingInvested += _amountInvestment;
        IERC20(stablecoin).transferFrom(treasury, address(this), _amountInvestment);
    }   

    /**
    * @dev function for owner (treasury) to remove funds 
     */
    function removeFunds(uint256 _amountToRemove) public virtual onlyOwner{
        require(underlyingInvested > underlyingExposedToSwaps + _amountToRemove, "There's not enough free assets in this strategy to remove this amount"); 
    }

    /**
    * @dev function to buy swap on the strategy. Can only be done if it's free
     */
    function buySwap(uint256 _amountUnderlying) public virtual{
        require(underlyingInvested > underlyingExposedToSwaps + _amountUnderlying, "There's not enough free assets in this strategy to invest this amount"); 
        underlyingExposedToSwaps += _amountUnderlying;
        _issueSwap(msg.sender, _amountUnderlying);
    }

    /**
    * @dev handles logic of issuing swap
     */
    function _issueSwap(address _issueTo, uint _amountUnderlying) internal virtual{
        // issue NFT with supperfuild superapp
        // and send other end of NFT to treasury
    }
}