//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTWhitelist is ERC721Holder, Ownable {
 
    // merkleRoot to validate the proof
    bytes32 public merkleRoot;

    // mapping of address who have claimed;
    mapping (address => uint256) public claimed;

    uint32 public fromTokenId;
    uint32 public toTokenId;
    uint32 public currentTokenId;
    uint32 public maxAllowedToClaim = 1;
    uint128 public salePrice;

    address public fundMgr;
    bool public saleActive = false;
 
    error NotWhitelisted();

    event Claimed(address indexed claimer, uint256 indexed tokenId);
    event RolledOver(bool status);

    constructor(bytes32 _merkleRoot, address _fundMgr) {
        merkleRoot = _merkleRoot;
        fundMgr = _fundMgr;
    }

    function claim(address token, bytes32[] calldata proof) payable external {
       address toAddress = msg.sender;
       require(saleActive, "Not started");
       require(msg.sender == tx.origin, "Bot not allowed");
       require(claimed[toAddress] < maxAllowedToClaim, "Already claimed");
       require(currentTokenId <= toTokenId, "Sold out");
       require(msg.value == salePrice, "Invalid pay");

       // verify merkle proof
       bool isValid = verifyProof(toAddress, proof);
       if(!isValid) revert  NotWhitelisted();

       IERC721(token).safeTransferFrom(address(this), toAddress, currentTokenId++);

       claimed[toAddress] = claimed[toAddress] + 1;

       emit Claimed(toAddress, currentTokenId);
    }

    function verifyProof(address user, bytes32[] calldata proof) public view returns(bool){
        bytes32 leaf = keccak256(abi.encodePacked(user));
        bool isValid = MerkleProof.verify(proof, merkleRoot, leaf);
        return isValid;
    }

    function flipSaleStatus() external onlyOwner {
        saleActive = !saleActive;

        emit RolledOver(saleActive);
    }

    function setTokenScope(uint32 _fromTokenId, uint32 _toTokenId, bool resetCurrentTokenId) external onlyOwner {
        require(_toTokenId >= _fromTokenId, "Invalid token scope");

        fromTokenId = _fromTokenId;
        toTokenId = _toTokenId;
        if (resetCurrentTokenId) {
            currentTokenId = _fromTokenId;
        }
    }

    function setSalePrice(uint128 _salePrice) external onlyOwner {
        salePrice = _salePrice;
    }

    function setMaxAllowedToClaim(uint32 _claimNumber) external onlyOwner {
        maxAllowedToClaim = _claimNumber;
    }

    function withdraw() external {
        payable(fundMgr).transfer(address(this).balance);
    }

    function changeMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        require( _merkleRoot != bytes32(0), "merkleRoot is the zero bytes32");
        merkleRoot = _merkleRoot;
    }

    function updateFundMgr(address newFundMgr) external onlyOwner {
        fundMgr = newFundMgr;
    }
}
