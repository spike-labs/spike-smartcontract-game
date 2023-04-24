// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract PaymentMaster is Ownable2Step {
    using SafeERC20 for IERC20;

    error IllegalState();
    error InvalidPay();
    error Unauthorized(address account);
    error PayNotEnough();
    error IllegalArgument();
    error NoEnoughBalance();

    event WhiteList(IERC20 token, bool enabled);
    event RenewService(uint256 moduleId, address user, address moduleOwner, IERC20 payToken, uint256 payAmount);
    event CancelService(uint256 moduleId, address user);
    event FeeStructureUpdate(uint256 moduleId, IERC20 payToken, uint256 feePerUnit, bool isStreamPay);

    mapping(IERC20 => bool) public paymentTokenWhitelist;

    uint256 public commissionRatio;
    mapping(IERC20 => uint256) public commissionBalance;
    address public paymentOwner;

    struct FeeStructure {
        uint256 feePerUnit;
        bool isStreamPay;
        IERC20 payToken;
    }

    struct StreamPayBalance {
        uint256 balance;
        uint256 updateTime;
    }

    // account => token => amount
    mapping(address => mapping(IERC20 => uint256)) revenueBalance;
    // moduleId => feeStructure
    mapping(uint256 => FeeStructure) public moduleFeeStructure;
    // account => moduleId => streamPayBalance
    mapping(address => mapping(uint256 => StreamPayBalance)) public userModuleStreamPayBalance;
    mapping(address => mapping(uint256 => bool)) public userModuleOneTimePaid;
    
    modifier onlyPaymentOwner {
        if (msg.sender != paymentOwner) revert Unauthorized(msg.sender);
        _;
    }

    function renewService(uint256 moduleId, uint256 amount) external {
        IERC20 payToken = moduleFeeStructure[moduleId].payToken;
        address user = msg.sender;
        payToken.safeTransferFrom(user, address(this), amount);
        address moduleOwner = IERC721(paymentOwner).ownerOf(moduleId);
     
        if (moduleFeeStructure[moduleId].isStreamPay) {     
            userModuleStreamPayBalance[user][moduleId].balance += amount;
            userModuleStreamPayBalance[user][moduleId].updateTime = block.timestamp;
        } else {
            (uint256 commissionAmount, uint256 pureFeeAmount) = _getFeeDistribution(amount);
            commissionBalance[payToken] += commissionAmount;
            if (moduleFeeStructure[moduleId].feePerUnit != amount) revert InvalidPay();
            revenueBalance[moduleOwner][payToken] += pureFeeAmount;
            userModuleOneTimePaid[user][moduleId] = true;
        }

        emit RenewService(moduleId, user, moduleOwner, payToken, amount);
    }

    function cancelService(uint256 moduleId, address moduleOwner) external {
        address user = msg.sender;
        if (!moduleFeeStructure[moduleId].isStreamPay) return;
        uint256 payBalance = userModuleStreamPayBalance[user][moduleId].balance;
        if (payBalance == 0) {
            return;
        }
        IERC20 payToken = moduleFeeStructure[moduleId].payToken;
        uint256 needToPay = _needToPay(moduleId, user);
        if (needToPay <= payBalance) {
            userModuleStreamPayBalance[user][moduleId].balance -= needToPay;
            revenueBalance[moduleOwner][payToken] += needToPay;
            payToken.transfer(user, userModuleStreamPayBalance[user][moduleId].balance);
        } else {
            revert NoEnoughBalance();
        }

        emit CancelService(moduleId, user);
    }

    function _needToPay(uint256 moduleId, address user) view internal returns (uint256) {
        uint256 feePerUnit = moduleFeeStructure[moduleId].feePerUnit;
        uint256 lastPayTime = userModuleStreamPayBalance[user][moduleId].updateTime;
        if (lastPayTime == 0) return feePerUnit * 3600;
        uint256 eslapedTime = block.timestamp - lastPayTime;
        uint256 needToPay = eslapedTime * moduleFeeStructure[moduleId].feePerUnit;
        return needToPay;
    }

    function checkService(uint256 moduleId, address user, address moduleOwner) external onlyPaymentOwner {
        if (!moduleFeeStructure[moduleId].isStreamPay) {
            if (moduleFeeStructure[moduleId].feePerUnit > 0 && !userModuleOneTimePaid[user][moduleId]) revert NoEnoughBalance();
            return;
        }
        uint256 payBalance = userModuleStreamPayBalance[user][moduleId].balance;
        IERC20 payToken = moduleFeeStructure[moduleId].payToken;
        uint256 needToPay = _needToPay(moduleId, user);
        if (needToPay > payBalance) revert NoEnoughBalance();
        (uint256 commissionAmount, uint256 pureFeeAmount) = _getFeeDistribution(needToPay);
        commissionBalance[payToken] += commissionAmount;
        userModuleStreamPayBalance[user][moduleId].balance -= needToPay;
        revenueBalance[moduleOwner][payToken] += pureFeeAmount;
    }

    function userPaid(uint256 moduleId, address user) view external returns (bool, uint256) {
        if (moduleFeeStructure[moduleId].isStreamPay) {
            uint256 payBalance = userModuleStreamPayBalance[user][moduleId].balance;
            uint256 needToPay = _needToPay(moduleId, user); 
            return (userModuleStreamPayBalance[user][moduleId].balance > 0, payBalance >= needToPay ? 0 : needToPay - payBalance);
        }
        bool hasPaid = userModuleOneTimePaid[user][moduleId];
        return (hasPaid, hasPaid ? 0 : moduleFeeStructure[moduleId].feePerUnit);
    }

    function withdrawRevenue(IERC20 payToken, uint256 amount) external {
        revenueBalance[msg.sender][payToken] -= amount;

        payToken.safeTransfer(msg.sender, amount);
    }

    function withdrawCommission(IERC20 payToken, address to) external onlyOwner {
        uint256 totalCommission = commissionBalance[payToken];
        commissionBalance[payToken] = 0;
        payToken.safeTransfer(to, totalCommission);
    } 

    function getBalance(IERC20 payToken, address account) view external returns (uint256) {
        return revenueBalance[account][payToken];
    }

    function getRevenue(address acccount, IERC20 payToken) view external returns (uint256) {
        return revenueBalance[acccount][payToken];
    }

    function configureFeeStructure(uint256 moduleId, IERC20 payToken, uint256 feePerUnit, bool isStreamPay) external onlyPaymentOwner {
        if (!paymentTokenWhitelist[payToken]) revert IllegalArgument();
        moduleFeeStructure[moduleId].payToken = payToken;
        moduleFeeStructure[moduleId].feePerUnit = feePerUnit;
        moduleFeeStructure[moduleId].isStreamPay = isStreamPay;

        emit FeeStructureUpdate(moduleId, payToken, feePerUnit, isStreamPay);
    }

    function configureCommissionRatio(uint256 newCommissionRatio) external onlyOwner {
        commissionRatio = newCommissionRatio;
    }

    function setPaymentOwner(address paymentOwner_) external {
        if (paymentOwner != address(0x0)) revert IllegalState();
        paymentOwner = paymentOwner_;
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
        } else {
            pureFeeAmount = feeAmount;
        }
    }
}