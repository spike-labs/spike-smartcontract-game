// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract PaymentMaster is Ownable2Step {
    error PayNotEnough();
    error IllegalArgument();
    error NoEnoughBalance();

    event WhiteList(IERC20 token, bool enabled);
    event RenewService(uint256 moduleId, address user, address moduleOwner, IERC20 payToken, uint256 commissionAmount, uint256 pureFeeAmount);
    event CancelService(uint256 moduleId, address user);

    mapping(IERC20 => bool) public paymentTokenWhitelist;

    uint256 commissionRatio;
    uint256 commissionBalance;

    struct FeeStructure {
        mapping(IERC20 => uint256) feePerUnit;
        bool isStreamPay;
    }

    struct StreamPayBalance {
        uint256 balance;
        uint256 updateTime;
        IERC20 payToken;
    }

    // account => token => amount
    mapping(address => mapping(IERC20 => uint256)) revenueBalance;
    // moduleId => feeStructure
    mapping(uint256 => FeeStructure) moduleFeeStructure;
    // account => moduleId => streamPayBalance
    mapping(address=> mapping(uint256 => StreamPayBalance)) userModuleStreamPayBalance;
    
    function renewService(uint256 moduleId, address user, address moduleOwner, IERC20 payToken, uint256 amount) external {
        if (!paymentTokenWhitelist[payToken]) revert IllegalArgument();

        payToken.transferFrom(user, address(this), amount);
        (uint256 commissionAmount, uint256 pureFeeAmount) = _getFeeDistribution(amount);
        commissionBalance += commissionAmount;
        if (moduleFeeStructure[moduleId].isStreamPay) {
            if (address(userModuleStreamPayBalance[user][moduleId].payToken) == address(0x0) || userModuleStreamPayBalance[user][moduleId].balance == 0) {
                userModuleStreamPayBalance[user][moduleId].payToken = payToken;
            } else {
                if (userModuleStreamPayBalance[user][moduleId].payToken != payToken) {
                    revert IllegalArgument();
                }
            }
            
            userModuleStreamPayBalance[user][moduleId].balance += pureFeeAmount;
            userModuleStreamPayBalance[user][moduleId].updateTime = block.timestamp;
        } else {
            if (moduleFeeStructure[moduleId].feePerUnit[payToken] > amount) revert PayNotEnough();
            revenueBalance[moduleOwner][payToken] += pureFeeAmount;
        }

        emit RenewService(moduleId, user, moduleOwner, payToken, commissionAmount, pureFeeAmount);
    }

    function cancelService(uint256 moduleId, address user, address moduleOwner) external {
        if (!moduleFeeStructure[moduleId].isStreamPay) return;
        uint256 payBalance = userModuleStreamPayBalance[user][moduleId].balance;
        if (payBalance == 0) {
            return;
        }
        IERC20 payToken = userModuleStreamPayBalance[user][moduleId].payToken;
        uint256 lastPayTime = userModuleStreamPayBalance[user][moduleId].updateTime;
        uint256 eslapedTime = block.timestamp - lastPayTime;

        uint256 needToPay = eslapedTime * moduleFeeStructure[moduleId].feePerUnit[payToken];
        if (needToPay <= payBalance) {
            userModuleStreamPayBalance[user][moduleId].balance -= needToPay;
            revenueBalance[moduleOwner][payToken] += needToPay;
            payToken.transfer(user, userModuleStreamPayBalance[user][moduleId].balance);
        } else {
            revert NoEnoughBalance();
        }

        emit CancelService(moduleId, user);
    }

    function checkService(uint256 moduleId, address user, address moduleOwner) external {
        if (!moduleFeeStructure[moduleId].isStreamPay) return;
        uint256 payBalance = userModuleStreamPayBalance[user][moduleId].balance;
        IERC20 payToken = userModuleStreamPayBalance[user][moduleId].payToken;
        uint256 lastPayTime = userModuleStreamPayBalance[user][moduleId].updateTime;
        uint256 eslapedTime = block.timestamp - lastPayTime;
        uint256 needToPay = eslapedTime * moduleFeeStructure[moduleId].feePerUnit[payToken];
        if (needToPay > payBalance) revert NoEnoughBalance();
        userModuleStreamPayBalance[user][moduleId].balance -= needToPay;
        revenueBalance[moduleOwner][payToken] += needToPay;
    }

    function withdraw(IERC20 payToken, uint256 amount) external {
        revenueBalance[msg.sender][payToken] -= amount;

        payToken.transfer(msg.sender, amount);
    }

    function getBalance(IERC20 payToken, address account) view external returns (uint256) {
        return revenueBalance[account][payToken];
    }

    function configureFeeStructure(uint256 moduleId, IERC20 payToken, uint256 feePerUnit, bool isStreamPay) external {
        moduleFeeStructure[moduleId].feePerUnit[payToken] = feePerUnit;
        moduleFeeStructure[moduleId].isStreamPay = isStreamPay;
    }

    function addTokenToWhitelist(IERC20 token) external onlyOwner {
        paymentTokenWhitelist[token] = true;

        emit WhiteList(token, true);
    }

    function removeTokenFromWhitelist(IERC20 token) external onlyOwner {
        paymentTokenWhitelist[token] = false;

        emit WhiteList(token, false);
    }

    function _getFeeDistribution(uint256 feeAmount) internal view returns (uint256 commissionAmount, uint256 pureFeeAmount) {
        if (commissionRatio != 0) {
            commissionAmount = feeAmount * commissionRatio / 10000;
            pureFeeAmount = feeAmount - commissionAmount;
        }
    }
}