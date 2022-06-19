interface IStrategy{
    function minCollateral() external returns(uint);
    function ONE_HUNDRED_PERCENT() external returns(uint);
    
    function fund(uint256 _amountInvestment) external;
    function getPriceUnderlyingUSD(uint _underlyingAm) external view returns(int);
    function closeSwap(uint256 _amountToRemove) external;
    function removeFunds(uint256 _amountToRemove, address _receiver) external;
    function getAmountOfUnderlyingForUSD(int _amount) external view returns(int);
}