// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IRiskControlStrategy.sol";
import "./Ownable.sol";

contract DefaultRiskControlStrategy is IRiskControlStrategy, Ownable {
    bool public paused;

    event Paused(address account, bool paused);

    function isRisky(address token, address user, uint256 amount, address admin) external view returns (bool) {
        token;
        user;
        amount;
        admin;
        return paused;
    }

    function isRiskyNFT(address token, address user, uint256 tokenId, address admin) external view returns (bool) {
        token;
        user;
        tokenId;
        admin;
        return paused;
    }

    function setPaused(bool pause) external onlyOwner {
        paused = pause;

        emit Paused(msg.sender, pause);
    }
}