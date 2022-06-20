// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITreasury{
    function stablecoin() external returns(IERC20);
}

interface ISwaps{
    function newSwap(address _receiver, address _payer, int96 _requiredFlowRate, uint _amountUnderlying) external;
}

/**
* @title StrategyStandard
* @author Caron Case (carsonpcase@gmail.com)
    contract to standardize what strategies do 
*/
abstract contract StrategyStandard is Ownable{
    uint constant ONE_HUNDRED_PERCENT = 100;

    address public immutable treasury;
    address internal stablecoin;
    uint256 public underlyingInvested;
    uint256 public underlyingExposedToSwaps;
    ISwaps public swaps;

    constructor(address _treasury) Ownable(){
        treasury = _treasury;
        stablecoin = address(ITreasury(_treasury).stablecoin());
    }

    modifier onlySwaps(){
        require(msg.sender == address(swaps), "StrategyStandard: Only Swaps contract can call this function");
        _;
    }

    /// @dev not a variable so it can be overriden
    function minColatearl() external view virtual returns(uint){
        return 0;
    }

    function getPriceUnderlyingStable(uint _underlyingAm) external view virtual returns(int){
        return 1;
    }

    function getAmountOfUnderlyingForStable(int _amount) public view virtual returns(int){
        return 1;
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
    function removeFunds(uint256 _amountToRemove, address _receiver) public virtual onlyOwner{
        require(underlyingInvested > underlyingExposedToSwaps + _amountToRemove, "There's not enough free assets in this strategy to remove this amount"); 
    }

    function closeSwap(uint256 _amountToRemove) public virtual onlySwaps{
        underlyingExposedToSwaps -= _amountToRemove;
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