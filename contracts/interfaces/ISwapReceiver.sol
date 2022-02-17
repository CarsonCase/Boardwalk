import {
    ISuperToken,
    ISuperfluid
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

interface ISwapReceiver{

    function verifyNewSwap(address _swapCreator, uint _amountUnderlying) external view returns(bool);
    function settle(int _usdSettlement, address _recipient) external;
}