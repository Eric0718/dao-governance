// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract CryaToken is ERC20Votes {
    address admin;
    uint256 public constant _totalSupply = 2000000000e18;

    constructor(address lockAddress) ERC20("CryaToken", "CRYA") ERC20Permit("CryaToken") {
        admin = msg.sender;
        _mint(lockAddress, _totalSupply);
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

    function _burn(address account, uint256 amount) internal override(ERC20Votes) {
        super._burn(account, amount);
    }

    function mint(address to,uint256 amount)public{
        require(msg.sender == admin,"Only admin can mint!");
        super._mint(to, amount);
    }
}