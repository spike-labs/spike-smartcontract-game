// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Ownable.sol";
import "./IRiskControlStrategy.sol";

contract GameVault is Ownable, ReentrancyGuard, ERC721Holder {
    using SafeERC20 for IERC20;

    mapping(address => bool) public admins;
    IRiskControlStrategy public riskControlStrategy;

    event AdminEnabled(address admin, bool enabled);
    event Withdraw(address token, address from, address to, uint256 amount);
    event WithdrawNFT(address token, address from, address to, uint256 tokenId);

    struct TokenBalance {
        address token;
        uint256 balance;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender], "!admin");
        _;
    }

    constructor() {
        admins[msg.sender] = true;
    }

    function batchWithdraw(address token, address payable[] memory recipients, uint[] memory amounts) external onlyAdmin nonReentrant {
        require(recipients.length == amounts.length, "recipient & amount arrays must be the same length");

        for (uint i = 0; i < recipients.length; i++) {
            withdrawInternal(token, recipients[i], amounts[i]);
        }  
    }

    function batchWithdraw(address[] memory tokens, address payable[] memory recipients, uint[] memory amounts) external onlyAdmin nonReentrant{
        require(tokens.length == recipients.length && recipients.length == amounts.length, "inconsistent length");

        for (uint i = 0; i < recipients.length; i++) {
            withdrawInternal(tokens[i], recipients[i], amounts[i]);
        }  
    }

    function withdraw(address token, address payable recipient, uint256 amount) external onlyAdmin nonReentrant{
        withdrawInternal(token, recipient, amount);
    }

    function withdrawInternal(address token, address payable recipient, uint256 amount) internal {
        if (address(riskControlStrategy) != address(0x0)) {
            require(!riskControlStrategy.isRisky(token, recipient, amount, msg.sender), "risky operation");
        }

        if (address(token) == address(0x0)) {
            Address.sendValue(recipient, amount);
        } else {
            IERC20(token).safeTransfer(recipient, amount);
        }
        emit Withdraw(token, address(this), recipient, amount);
    }

    function withdrawNFT(address token, address recipient, uint256 tokenId) external onlyAdmin nonReentrant {
        withdrawNFTInternal(token, recipient, tokenId);
    }

    function withdrawNFTInternal(address token, address recipient, uint256 tokenId) internal onlyAdmin {
        if (address(riskControlStrategy) != address(0x0)) {
            require(!riskControlStrategy.isRiskyNFT(token, recipient, tokenId, msg.sender), "risky operation");
        }
        IERC721(token).safeTransferFrom(address(this), recipient, tokenId);
        emit WithdrawNFT(token, address(this), recipient, tokenId);
    }

    function batchWithdrawNFT(address[] memory tokens, address[] memory recipients, uint256[] memory tokenIds) external onlyAdmin nonReentrant {
        require(tokens.length == recipients.length && tokenIds.length == recipients.length, "inconsistent length");

        for (uint i = 0; i < recipients.length; i++) {
            withdrawNFTInternal(tokens[i], recipients[i], tokenIds[i]);
        }
    }

    function setRiskControlStrategy(IRiskControlStrategy _riskControlStrategy) external onlyOwner {
        riskControlStrategy = _riskControlStrategy;
    }

    function enableAdmin(address _addr) external onlyOwner {
        admins[_addr] = true;

        emit AdminEnabled(_addr, true);
    }

    function disableAdmin(address _addr) external onlyOwner {
        admins[_addr] = false;

        emit AdminEnabled(_addr, false);
    }

    function getTokenBalance(address token) view public returns (uint256) {
        if (token == address(0x0)) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    function getTokenBalances(address[] memory tokens) view external returns (TokenBalance[] memory) {
        TokenBalance[] memory tokenBalances = new TokenBalance[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            tokenBalances[i].token = tokens[i];
            tokenBalances[i].balance = getTokenBalance(tokens[i]);
        }
        return tokenBalances;
    }

    receive() external payable {
    }
}