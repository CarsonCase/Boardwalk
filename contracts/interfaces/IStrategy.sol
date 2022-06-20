interface IStrategy{
    function minCollateral() external view returns(uint);
    function ONE_HUNDRED_PERCENT() external pure returns(uint);

    function fund(uint256 _amountInvestment) external;
    function getPriceUnderlyingStable(uint _underlyingAm) external view returns(int);
    function closeSwap(uint256 _amountToRemove) external;
    function removeFunds(uint256 _amountToRemove, address _receiver) external;
    function getAmountOfUnderlyingForStable(int _amount) external view returns(int);
}