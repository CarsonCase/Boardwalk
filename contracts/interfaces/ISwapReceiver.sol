import {
    ISuperToken,
    ISuperfluid
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

interface ISwapReceiver{

    function verifyNewSwap(address _swapCreator, uint _amountUnderlying) external view returns(bool);
    function settle(int _usdSettlement, uint _collateralToFree, address _recipient) external;
    function getAvailableCollateral(address _of) external view returns(uint);
    function lockCollateral(address _of, uint _amount) external;
}