// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @title NFT definition for game component
 * @author Spike Labs
 */
contract GameComponentNFT is ERC721Enumerable, ERC2981 { 
    event UsageFeeUpdated(uint256 tokenId, uint256 oldUsageFee, uint256 newUsageFee);
    event MintTokenRoyaltyFeeUpdated(uint256 tokenId, uint256 oldMintTokenRoyaltyFee, uint256 newMintTokenRoyaltyFee);
    event ToggleTokenMintAllowed(uint256 tokenId, bool newState);

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    struct MintRoyaltyInfo {
        uint256 mintRoyaltyFee;
        bool mintAllowed;
    }

    // Used to construct tokenURI together with token id
    string private _baseTokenURI;

    // Optional mapping for token URIs
    mapping(uint256 tokenId => string tokenURI) private _tokenURIs;
    mapping(uint256 => MintRoyaltyInfo) public tokenMintRoyaltyInfo;
    mapping(uint256 tokenId => uint256 tokenUsageFee) public usageFee;
    mapping(address userAccount => mapping(uint256 tokenId => bool hasPaidUsageFee)) private _isUserPaid;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * Pay fees to pay the game
     * @param tokenId The game or game component token id
     */
    function payToPlay(uint256 tokenId) external payable {
        require(usageFee[tokenId] == msg.value, "Invalid pay");
        Address.sendValue(payable(ownerOf(tokenId)), msg.value);
        _isUserPaid[msg.sender][tokenId] = true;
    }

    /**
     * Check whether the user has paid the usage fee
     * @param user Game player
     * @param tokenId Game or game component token id
     */
    function isUserPaid(address user, uint256 tokenId) view external returns (bool) {
        return _isUserPaid[user][tokenId];
    }

    /**
     * Update game usage fee
     * @param tokenId Game or game component token id
     * @param newUsageFee Game or game component usage fee
     */
    function configureUsageFee(uint256 tokenId, uint256 newUsageFee) public {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");

        emit UsageFeeUpdated(tokenId, usageFee[tokenId], newUsageFee);

        usageFee[tokenId] = newUsageFee;


    }

    /**
     * Mint new game or game component based on existing one
     * @param _tokenURI Token URI for new game or game component token
     * @param baseId The game or game component to be minted with
     * @param mintRoyaltyFee The mint royalty fee for new token
     * @param marketRoyaltyFraction Royalty setting per ERC2981
     * @param newUsageFee The game or game component usage fee
     */
    function mint(string memory _tokenURI, uint256 baseId, uint256 mintRoyaltyFee, uint96 marketRoyaltyFraction, uint256 newUsageFee) external payable {
        if (baseId != 0) {
            require(tokenMintRoyaltyInfo[baseId].mintAllowed, "Invalid mint base id");

            address baseTokenOwner = ownerOf(baseId);
            require(baseTokenOwner != address(0x0));
            MintRoyaltyInfo storage mintRoyaltyInfo = tokenMintRoyaltyInfo[baseId];
            require(msg.value == mintRoyaltyInfo.mintRoyaltyFee);
            Address.sendValue(payable(baseTokenOwner), msg.value);
        }
        require(marketRoyaltyFraction < 10000);
        address receiver = msg.sender;
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        mintInternal(receiver, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        _setTokenRoyalty(tokenId, receiver, marketRoyaltyFraction);
        setMintTokenRoyalty(tokenId, mintRoyaltyFee);
        toggleMintAllowed(tokenId);
        configureUsageFee(tokenId, newUsageFee);
    }

    function mintInternal(address to, uint256 tokenId) internal {
        require(!_exists(tokenId), "Already minted");

        _safeMint(to, tokenId);
    }
    
    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];

        // If there is no base URI, return the token URI.
        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;
        }

        return super.tokenURI(tokenId);
    }

    /**
     * @dev Set royalty fee ratio for specific NFT
     * @param tokenId The specific NFT token id
     * @param receiver The royalty fee receiver
     * @param feeNumerator The royalty fee ratio, should be set to 200 if the ratio is 2%
     */
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external {
        super._setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /**
     * @dev Set mint royalty fee amount for specific NFT
     * @param tokenId The specific NFT token id
     * @param newMintRoyaltyFee The royalty fee amount
     */
    function setMintTokenRoyalty(uint256 tokenId, uint256 newMintRoyaltyFee) public {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");

        emit MintTokenRoyaltyFeeUpdated(tokenId, tokenMintRoyaltyInfo[tokenId].mintRoyaltyFee, newMintRoyaltyFee);

        tokenMintRoyaltyInfo[tokenId].mintRoyaltyFee = newMintRoyaltyFee;
    }

    /**
     * @dev Set to be a mint base or not for specific NFT
     * @param tokenId The specific NFT token id
     */
    function toggleMintAllowed(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        tokenMintRoyaltyInfo[tokenId].mintAllowed = !tokenMintRoyaltyInfo[tokenId].mintAllowed;

        emit ToggleTokenMintAllowed(tokenId, tokenMintRoyaltyInfo[tokenId].mintAllowed);
    }

    /**
     * @dev Return the token list owner by specific user
     * @param owner The specific user address
     */
    function balanceOfTokens(address owner) view external returns (uint256[] memory) {
        uint256 tokenNum = balanceOf(owner);
        uint256[] memory ownedTokens = new uint256[](tokenNum);

        for (uint256 i = 0; i < tokenNum; i++) {
            ownedTokens[i] = tokenOfOwnerByIndex(owner, i);
        }
        return ownedTokens;
    }
    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
}
