// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRiskControlStrategy {
    function isRisky(address token, address user, uint256 amount, address admin) external view returns (bool);
    function isRiskyNFT(address token, address user, uint256 tokenId, address admin) external view returns (bool);
}