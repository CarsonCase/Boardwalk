interface IStrategy{
    function fund(uint256 _amountInvestment) external;
    function getPriceUnderlyingUSD(uint _underlyingAm) external view returns(int);
    function closeSwap(uint256 _amountToRemove) external;
    function removeFunds(uint256 _amountToRemove, address _receiver) external;
}