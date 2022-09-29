// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "./ERC4907/ERC4907.sol";
import "./Ownable.sol";

contract GameNFT is ERC4907, ERC2981, Ownable {
    // Used to construct tokenURI together with token id
    string private _baseTokenURI;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;
    mapping(address => bool) public admins;
    uint256 public totalSupply;

    event AdminEnabled(address admin, bool enabled);

    modifier onlyAdmin() {
        require(admins[msg.sender], "!admin");
        _;
    }

    constructor(string memory name, string memory symbol) ERC4907(name, symbol) {
        admins[msg.sender] = true;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC4907, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mint(uint256 tokenId, address to) external onlyAdmin {
        mintInternal(to, tokenId);
    }

    function batchMint(uint256[] memory tokenIds, address[] memory receivers) external onlyAdmin {
        require(tokenIds.length == receivers.length, "inconsistent length");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            mintInternal(receivers[i], tokenIds[i]);
        }
    }

    function mint(uint256 tokenId, address to, string memory _tokenURI) external onlyAdmin {
        mintInternal(to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
    }

    function batchMint(uint256[] memory tokenIds, address to, string[] memory tokenURIs) external onlyAdmin {
        require(tokenIds.length == tokenURIs.length, "inconsistent length");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            mintInternal(to, tokenIds[i]);
            _setTokenURI(tokenIds[i], tokenURIs[i]);
        }
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
     * @dev Set default royalty fee ratio
     * @param receiver The royalty fee receiver
     * @param feeNumerator The royalty fee ratio, should be set to 200 if the ratio is 2%
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyAdmin {
        super._setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @dev Set royalty fee ratio for specific NFT
     * @param tokenId The specific NFT token id
     * @param receiver The royalty fee receiver
     * @param feeNumerator The royalty fee ratio, should be set to 200 if the ratio is 2%
     */
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyAdmin {
        super._setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /**
     * @dev Set token URI for specific NFT
     * @param tokenId The specific NFT token id
     * @param _tokenURI The token URI to be set
     */
    function setTokenURI(uint256 tokenId, string memory _tokenURI) external onlyAdmin {
        _setTokenURI(tokenId, _tokenURI);
    }

    /**
     * @dev Set the base token URI, the base URI is used to construct token URI be default
     * @param baseURI_ The base token URI to be set
     */
    function setBaseTokenURI(string memory baseURI_) external onlyAdmin {
         _baseTokenURI = baseURI_;
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

    function enableAdmin(address _addr) external onlyOwner {
        admins[_addr] = true;

        emit AdminEnabled(_addr, true);
    }

    function disableAdmin(address _addr) external onlyOwner {
        admins[_addr] = false;

        emit AdminEnabled(_addr, false);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._afterTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            totalSupply += 1;
        }
        if (to == address(0)) {
            totalSupply -= 1;
        }
    }
}
