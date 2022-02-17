// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GovernanceToken is ERC20Votes, Ownable {
    
    IERC20 public token;
    uint public devShare = 12 ether;

    constructor(address _token)
        ERC20("GovernanceToken", "GT")
        ERC20Permit("GovernanceToken")
        Ownable()
    {
        token = IERC20(_token);
        _mint(msg.sender, devShare);
    }

    // Leave the bar. Claim back your TOKENs.
    // Unlocks the staked + gained Token and burns xToken
    function leave(uint256 _share) external {
        // Gets the amount of xToken in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Token the xToken is worth
        uint256 what = (_share * token.balanceOf(address(this))) / (totalShares);
        _burn(msg.sender, _share);
        token.transfer(msg.sender, what);
    }

    // silly little function to be able to withdrawal your earnings while keeping the base amount.
    // this only leaves with profits then gives you back enough shares to be equal to what you initial investment was
    function withdrawal() external{
        uint256 _share = token.balanceOf(msg.sender);
        // Gets the amount of xToken in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Token the xToken is worth
        uint256 what = (_share * token.balanceOf(address(this))) / (totalShares);
        if(what > _share){
            token.transfer(msg.sender, what - _share);
            _burn(msg.sender, (_share * totalShares) / token.balanceOf(address(this)));
        }
    }

    function mint(address _to, uint256 _amount) external onlyOwner{
        _mint(_to, _amount);
    }

    // The functions below are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20Votes)
    {
        super._burn(account, amount);
    }
}
