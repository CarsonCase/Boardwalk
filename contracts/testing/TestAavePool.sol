// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";

interface ITestOracle{
    function priceOf(address _token) external view returns(int price, uint8 decimals);

}

contract TestAavePool is ERC20{

    uint public LTV = 8250;     //10000 is 100%
    ITestOracle public oracle;
    address public weth;

    constructor(ITestOracle _oracle, address _weth) ERC20("aTST", "Test Aave Pool Debt Token"){
        oracle = _oracle;
        weth = _weth;
    }

    receive() payable external{

    }

    function setLTV(uint _new) external{
        LTV = _new;
    }

    function supply(address _token, uint _amount, address _reciver, uint16 _interestMode) external{
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        _mint(_reciver, _amount);
    }

    function getReserveData(address _token) external returns(DataTypes.ReserveData memory reserveData){
        DataTypes.ReserveConfigurationMap memory reserveConfigMap;
        reserveConfigMap = DataTypes.ReserveConfigurationMap(0);
        reserveData = DataTypes.ReserveData(reserveConfigMap, 0, 0, 0, 0, uint40(block.timestamp), 0, 0, address(0), address(this), address(this), address(0), 0, 0, 0);
    }

  function getUserAccountData(address _user)
    external
    view
    virtual
    returns (
      uint256 totalCollateralBase,
      uint256 totalDebtBase,
      uint256 availableBorrowsBase,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    ){
        totalCollateralBase = 0;
        totalDebtBase = 0;
        currentLiquidationThreshold = 0;
        ltv = LTV;
        healthFactor = 0;

        (int price, uint8 decimals) = oracle.priceOf(weth);
        uint amAfterLTV = (balanceOf(_user) * LTV) / 10000;
        availableBorrowsBase = (amAfterLTV * 10**decimals) / uint(price);
    }

    function borrow(address _token, uint _toBorrow, uint _interestMode, uint16 _referralCode, address _receiver) external{
        if(_token == weth){
            payable(_receiver).transfer(_toBorrow);
        }else{
            IERC20(_token).transfer(_receiver, _toBorrow);
        }
    }
}