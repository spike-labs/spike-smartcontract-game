// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./payment/PaymentMaster.sol";

/**
 * @title NFT definition for game component
 * @author Spike Labs
 */
contract GameComponentNFT is ERC721Enumerable, ERC2981 { 
    error Unauthorized(address user);
    error NotMintBase(uint256 tokenId);
    error IllegalArgument();

    event UsageFeeUpdated(uint256 tokenId, uint256 oldUsageFee, uint256 newUsageFee);
    event MintTokenRoyaltyFeeUpdated(uint256 tokenId, uint256 oldMintTokenRoyaltyFee, uint256 newMintTokenRoyaltyFee);
    event ToggleTokenMintAllowed(uint256 tokenId, bool newState);

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // Used to construct tokenURI together with token id
    string private _baseTokenURI;

    // tokenId => tokenURI
    mapping(uint256 => string) private _tokenURIs;
    // tokenId => mintAllowed
    mapping(uint256 => bool) public tokenMintAllowed;
    // tokenId => baseId
    mapping(uint256 => uint256) public baseToken;

    PaymentMaster public usagePayment;
    // tokenId => subComponents
    mapping(uint256 => uint256[]) public tokenSubComponents;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        usagePayment = new PaymentMaster();
        usagePayment.transferOwnership(msg.sender);
        usagePayment.setPaymentOwner(address(this));
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
    function payToPlay(uint256 tokenId) external {
        usagePayment.checkService(tokenId, msg.sender, ownerOf(tokenId));
    }

    /**
     * Check whether the user has paid the usage fee
     * @param user Game player
     * @param tokenId Game or game component token id
     */
    function isUserPaid(address user, uint256 tokenId) view external returns (bool) {
        return usagePayment.userPaid(tokenId, user);
    }

    /**
     * Update game usage fee
     * @param tokenId Game or game component token id
     * @param usageFeePerUnit Game or game component usage fee
     */
    function configureUsageFee(uint256 tokenId, IERC20 payToken, uint256 usageFeePerUnit, bool isStreamPay) public {
        if (msg.sender != ownerOf(tokenId)) revert Unauthorized(msg.sender);

        usagePayment.configureFeeStructure(tokenId, payToken, usageFeePerUnit, isStreamPay);
    }

    /**
     * Mint new game or game component based on existing one
     * @param _tokenURI Token URI for new game or game component token
     * @param baseId The game or game component to be minted with
     * @param marketRoyaltyFraction Royalty setting per ERC2981
     * @param usageFeePerUnit The usage fee for new token
     * @param payToken The token used to pay usage fee
     */
    function mint(string memory _tokenURI, uint256 baseId, uint96 marketRoyaltyFraction, uint256 usageFeePerUnit, IERC20 payToken) external {
        if (baseId == 0 || !tokenMintAllowed[baseId]) revert NotMintBase(baseId);
        if (ownerOf(baseId) == address(0x0)) revert IllegalArgument();

        usagePayment.checkService(baseId, msg.sender, ownerOf(baseId));
        mint(_tokenURI, marketRoyaltyFraction, usageFeePerUnit, payToken);
        baseToken[_tokenIdCounter.current()] = baseId;
    }

    function mint(string memory _tokenURI, uint96 marketRoyaltyFraction, uint256 usageFeePerUnit, IERC20 payToken) public {
        if (marketRoyaltyFraction >= 10000) revert IllegalArgument();
        _tokenIdCounter.increment();
        address minter = msg.sender;
        uint256 tokenId = _tokenIdCounter.current();
        mintInternal(minter, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        _setTokenRoyalty(tokenId, minter, marketRoyaltyFraction);
        toggleMintAllowed(tokenId);
        usagePayment.configureFeeStructure(tokenId, payToken, usageFeePerUnit, false);
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
        if (msg.sender != ownerOf(tokenId)) revert Unauthorized(msg.sender);

        super._setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /**
     * @dev Set to be a mint base or not for specific NFT
     * @param tokenId The specific NFT token id
     */
    function toggleMintAllowed(uint256 tokenId) public {
        if (msg.sender != ownerOf(tokenId)) revert Unauthorized(msg.sender);

        tokenMintAllowed[tokenId] = !tokenMintAllowed[tokenId];

        emit ToggleTokenMintAllowed(tokenId, tokenMintAllowed[tokenId]);
    }
    
    function addSubComponents(uint256 tokenId, uint256[] calldata subComponents) external {
        if (msg.sender != ownerOf(tokenId)) revert Unauthorized(msg.sender);

        for (uint256 i = 0; i < subComponents.length; i++) {
            tokenSubComponents[tokenId].push(subComponents[i]);
        }
    }

    function replaceSubComponent(uint256 tokenId, uint256 indexId, uint256 subComponent) external {
        if (msg.sender != ownerOf(tokenId)) revert Unauthorized(msg.sender);

        tokenSubComponents[tokenId][indexId] = subComponent;
    }

    function subComponentsLength(uint256 tokenId) external view returns (uint256) {
        return tokenSubComponents[tokenId].length;
    }

    function getSubComponents(uint256 tokenId) external view returns (uint256[] memory) {
        return tokenSubComponents[tokenId];
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
