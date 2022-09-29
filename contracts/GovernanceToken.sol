// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./Ownable.sol";

contract GovernanceToken is ERC20Burnable, Ownable {
    uint256 private immutable _cap;

    constructor(string memory name_, string memory symbol_, uint256 cap_) ERC20(name_, symbol_) {
        require(cap_ > 0, "cap is 0");
        _cap = cap_;
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

    function mint(address account, uint256 amount) external onlyOwner {
        require(ERC20.totalSupply() + amount <= cap(), "cap exceeded");
        _mint(account, amount);
    }
}