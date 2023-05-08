// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./DPStaking.sol";

contract DPRegistar is DPStaking {
    using Counters for Counters.Counter;

    Counters.Counter private dpIdCounter;

    event DPRegistered(uint256 dpId, address dpOwner, string dpEndpoint, string dpUrl);
    event DPUpdated(uint256 dpId, address operator, string newDpEndpoint, string newDpUrl);
    event DPUnregistered(uint256 dpId, address dpOwner);
    event OwnershipTransferStarted(uint256 dpId, address indexed previousOwner, address indexed newOwner);
    event OwnershipTransfered(uint256 dpId, address indexed previousOwner, address indexed newOwner);
    event UpdateRquiredStakeAmount(uint256 oldAmount, uint256 newAmount);

    enum DPStatus {
        Registered,
        UnRegistered
    }

    struct DPInfo {
        address owner;
        address pendingOwner;
        string dpEndpoint;
        string dpUrl;
        uint256 stakeAmount;
        DPStatus status;
    }

    // dpId => dpInfo
    mapping (uint256 => DPInfo) public dpInfo;

    uint256 public requiredStakeAmount;

    constructor(IERC20 stakingToken_) DPStaking(stakingToken_) {
    }
    /**
     * This method should be called by DP Owner to register DP node
     * The address used to register the DP will be treated as DP Owner
     * The DP Owner here should be the same as the address configured in DP node configuration file
     * One DP Owner could have multiple DP nodes
     * Each DP node will be assgined one unique id number
     * @param dpEndpoint The info to visit dp node
     * @param dpUrl The url to visit the APIs the dp provides
     */
    function register(string calldata dpEndpoint, string calldata dpUrl) external {
        address dpOwner = msg.sender;
        uint256 dpId = dpIdCounter.current();
        dpInfo[dpId].owner = dpOwner;
        dpInfo[dpId].dpEndpoint = dpEndpoint;
        dpInfo[dpId].dpUrl = dpUrl;
        dpInfo[dpId].status = DPStatus.Registered;
        dpIdCounter.increment();

        if (requiredStakeAmount > 0) {
            lockStake(dpId, requiredStakeAmount);
            dpInfo[dpId].stakeAmount = requiredStakeAmount;
        }
        emit DPRegistered(dpId, dpOwner, dpEndpoint, dpUrl);
    }

    function update(uint256 dpId, string calldata dpEndpoint, string calldata dpUrl) external {
        DPInfo storage currentDPInfo = dpInfo[dpId];
        address currentUser = msg.sender;
        if (currentDPInfo.owner != currentUser) revert Unauthorized(currentUser);

        currentDPInfo.dpEndpoint = dpEndpoint;
        currentDPInfo.dpUrl = dpUrl;

        emit DPUpdated(dpId, currentUser, dpEndpoint, dpUrl);
    }

    function transferOwner(uint256 dpId, address newOwner) external {
        DPInfo storage currentDPInfo = dpInfo[dpId];
        address currentUser = msg.sender;
        if (currentDPInfo.owner != currentUser) revert Unauthorized(currentUser);
        
        currentDPInfo.pendingOwner = newOwner;

        emit OwnershipTransferStarted(dpId, currentUser, newOwner);
    }

    function acceptOwner(uint256 dpId) external {
        DPInfo storage currentDPInfo = dpInfo[dpId];
        address currentUser = msg.sender;
        if (currentDPInfo.pendingOwner != currentUser) revert Unauthorized(currentUser);
        currentDPInfo.pendingOwner = address(0x0);
        currentDPInfo.owner = currentUser;

        emit OwnershipTransfered(dpId, currentDPInfo.owner, currentUser);
    }

    function unregister(uint256 dpId) external {
        DPInfo storage currentDPInfo = dpInfo[dpId];
        address currentUser = msg.sender;
        if (currentDPInfo.owner != currentUser) revert Unauthorized(currentUser);
        currentDPInfo.status = DPStatus.UnRegistered;

        if (currentDPInfo.stakeAmount > 0) {
            unlockStake(dpId, currentDPInfo.stakeAmount);
        }

        emit DPUnregistered(dpId, currentUser);
    }

    function setRequiredStakeAmount(uint256 amount) external onlyOwner {
        emit UpdateRquiredStakeAmount(requiredStakeAmount, amount);

        requiredStakeAmount = amount;
    }
}