// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
/**
 * @dev Required interface of a composable nft contract.
 */
interface IComposableNFT /* is IERC165, IERC721 */  {
    /**
     * @dev Emitted when `slotAssetAmount` of `slotAssetTokenId` is attached to one specific `slotId` of `tokenId`.
     */
    event AttachSlotAsset(uint tokenId, uint slotId, uint slotAssetTokenId, uint slotAssetAmount);

    /**
     * @dev Emitted when `slotAssetAmount` of `slotAssetTokenId` is detached from one specific `slotId` of `tokenId`.
     */
    event DetachSlotAsset(uint tokenId, uint slotId, uint slotAssetTokenId, uint slotAssetAmount);

    /**
     * @dev Attach specific `amount` of `slotAssetTokenId` to one `slotId` of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` should be one valid tokenId and the owner should be the caller.
     * - `slotId` should be properly defined.
     * - `slotAssetTokenId` should be one valid slot tokenId and the owner should be the caller.
     * - `amount` should be >=1, if the slot asset token is ERC721, amount shoule be 1; if the slot asset is ERC1155, the amount means the number of slot assets to be attached.
     *
     * Emits a {AttachSlotAsset} event.
     */
    function attachSlot(uint tokenId, uint slotId, uint slotAssetTokenId, uint amount) external;

    /**
     * @dev Remove the slot assets and transfer them to the caller
     */
    function detach(uint tokenId, uint slotId) external;

    /**
     * @dev Replace current slot asset with new asset with `slotAssetTokenId`
     */
    function replace(uint tokenId, uint slotId, uint slotAssetTokenId, uint amount) external;
}