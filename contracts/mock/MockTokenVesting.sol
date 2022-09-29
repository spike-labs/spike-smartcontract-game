// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../utils/TokenVesting.sol";

contract MockTokenVesting is TokenVesting {
    uint256 private currentTime;

    constructor(address token_) TokenVesting(token_) {
    }

    function increaseTime(uint256 timeInterval) external {
        uint256 _currentTime = getCurrentTime();
        if (currentTime == 0) {
            currentTime = _currentTime + timeInterval;
        } else {
            currentTime += timeInterval;
        }
    }

    function getCurrentTime() internal override view returns(uint256) {
        if (currentTime == 0) {
            return block.timestamp;
        }
        return currentTime;
    }
}