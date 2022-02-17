interface IStrategy{
    function fund(uint256 _amountInvestment) external;
    function getPriceUnderlyingUSD(uint _underlyingAm) external view returns(int);
}