// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./GameComponentNFT.sol";
import "./IComposableNFT.sol";

contract GameComposableNFT is IComposableNFT, GameComponentNFT, ERC721Holder, ERC1155Holder, Ownable {
    struct SlotInfo {
        uint slotId;
        address slotAssetAddress;
        uint slotAssetTokenId;
        uint slotAssetTokenAmount;
        bool slotFilled;
    }
    mapping(uint slotId => address slotAssetAddress) public slotAsset;
    uint[] public slots;

    // currentTokenId => slotId => slotAssetTokenId
    mapping(uint tokenId => mapping(uint slotId => uint slotAssetTokenId)) tokenSlotsData;
    mapping(uint tokenId => mapping(uint slotId => uint slotAssetTokenBalance)) tokenSlotsBalance;
    mapping(uint tokenId => mapping(uint slotId => bool isFilledWithSlotAsset)) tokenSlotsFilled;

    mapping (address => bool) public admins;

    event NewSlot(uint slotId, address assetTokenAddress);

    modifier onlyAdmin() {
        require(admins[msg.sender], "No admin permission");
        _;
    }

    constructor(string memory name, string memory symbol, address defaultAdmin) GameComponentNFT(name, symbol) {
        admins[defaultAdmin] = true;
        admins[msg.sender] = true;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155Receiver, GameComponentNFT) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function configureSlot(uint slotId, address assetTokenAddress) public onlyAdmin {
        require(ERC165Checker.supportsInterface(assetTokenAddress, type(IERC721).interfaceId) || 
                ERC165Checker.supportsInterface(assetTokenAddress, type(IERC1155).interfaceId), "Invalid asset address");
        require(slotAsset[slotId] == address(0x0), "Slot exists");

        slotAsset[slotId] = assetTokenAddress;
        slots.push(slotId);

        emit NewSlot(slotId, assetTokenAddress);
    }

    function configureSlots(uint[] memory slotIds, address[] memory assetTokenAddresses) external {
        for (uint i = 0; i < slotIds.length; i++) {
            configureSlot(slotIds[i], assetTokenAddresses[i]);
        }
    }

    function attachBatch(uint tokenId, uint[] memory slotIds, uint[] memory slotAssetTokenIds, uint[] memory amount) external {
        require(msg.sender == ownerOf(tokenId), "Not token owner");
        require(slotIds.length == slotAssetTokenIds.length, "Inconsistent length");
        require(slotAssetTokenIds.length == amount.length, "Inconsistent length");

        for (uint i = 0; i < slotIds.length; i++) {
            attachInternal(tokenId, slotIds[i], slotAssetTokenIds[i], amount[i]);
        }
    }

    function attachSlot(uint tokenId, uint slotId, uint slotAssetTokenId, uint amount) external {
        require(msg.sender == ownerOf(tokenId), "Not token owner");
        
        attachInternal(tokenId, slotId, slotAssetTokenId, amount);
    }

    function attachInternal(uint tokenId, uint slotId, uint slotAssetTokenId, uint amount) internal {
        address slotAssetAddress = slotAsset[slotId];
        require(slotAssetAddress != address(0x0), "Invliad slot id");

        if (is1155AssetSlot(slotId)) {
            tokenSlotsBalance[tokenId][slotId] += amount;
            if (!tokenSlotsFilled[tokenId][slotId]) {
                tokenSlotsData[tokenId][slotId] = slotAssetTokenId;
                tokenSlotsFilled[tokenId][slotId] = true;
            }

            emit AttachSlotAsset(tokenId, slotId, slotAssetTokenId, amount);
            return;
        }

        if (is721AssetSlot(slotId)) {
            require(!tokenSlotsFilled[tokenId][slotId], "Slot already filled");
            tokenSlotsData[tokenId][slotId] = slotAssetTokenId;
            tokenSlotsBalance[tokenId][slotId] = 1;
            tokenSlotsFilled[tokenId][slotId] = true;

            emit AttachSlotAsset(tokenId, slotId, slotAssetTokenId, amount);
            return;
        }

    }

    function detach(uint tokenId, uint slotId) public {
        address slotAssetAddress = slotAsset[slotId];
        require(slotAssetAddress != address(0x0), "Invliad slot id");
        require(msg.sender == ownerOf(tokenId), "Not token owner");
        require(tokenSlotsFilled[tokenId][slotId], "Slot not filled");

        if (is1155AssetSlot(slotId)) {
            emit DetachSlotAsset(tokenId, slotId, tokenSlotsData[tokenId][slotId], tokenSlotsBalance[tokenId][slotId]);

            tokenSlotsFilled[tokenId][slotId] = false;
            tokenSlotsBalance[tokenId][slotId] = 0;
            tokenSlotsData[tokenId][slotId] = 0;
            return;
        }

        if (is721AssetSlot(slotId)) {
            emit DetachSlotAsset(tokenId, slotId, tokenSlotsData[tokenId][slotId], tokenSlotsBalance[tokenId][slotId]);
            tokenSlotsFilled[tokenId][slotId] = false;
            tokenSlotsBalance[tokenId][slotId] = 0;
            tokenSlotsData[tokenId][slotId] = 0;
        }
    }

    function replace(uint tokenId, uint slotId, uint slotAssetTokenId, uint amount) external {
        detach(tokenId, slotId);
        attachInternal(tokenId, slotId, slotAssetTokenId, amount); 
    }

    function getTokenSlotsInfo(uint tokenId) external view returns (SlotInfo[] memory) {
        SlotInfo[] memory tokenSlotsInfo = new SlotInfo[](slots.length);
        uint currentSlotId;
        for (uint i = 0; i < slots.length; i++) {
            currentSlotId = slots[i];
            tokenSlotsInfo[i].slotId = currentSlotId;
            tokenSlotsInfo[i].slotAssetAddress = slotAsset[currentSlotId];
            tokenSlotsInfo[i].slotAssetTokenId = tokenSlotsData[tokenId][currentSlotId];
            tokenSlotsInfo[i].slotAssetTokenAmount = tokenSlotsBalance[tokenId][currentSlotId];
            tokenSlotsInfo[i].slotFilled = tokenSlotsFilled[tokenId][currentSlotId];   
        }
        return tokenSlotsInfo;
    }

    function enableAdmin(address newAdmin, bool flag) external onlyOwner {
        admins[newAdmin] = flag;
    }

    function slotsLength() external view returns (uint) {
        return slots.length;
    }

    function is1155AssetSlot(uint slotId) public view returns (bool) {
        return ERC165Checker.supportsInterface(slotAsset[slotId], type(IERC1155).interfaceId);
    }

    function is721AssetSlot(uint slotId) public view returns (bool) {
        return ERC165Checker.supportsInterface(slotAsset[slotId], type(IERC721).interfaceId);
    }
}