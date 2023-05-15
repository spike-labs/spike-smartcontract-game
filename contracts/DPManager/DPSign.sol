// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "./DPRegistar.sol";

contract DPSign {
    error InvalidDpState(uint256 dpId);
    error Unauthorized();
    error IllegalArgument();

    using Counters for Counters.Counter;
    enum ReqStatus {
        Default, // default value for placeholder
        Proposed,
        Accepted,
        Rejected,
        Canceled
    }
    struct ReqInfo {
        uint256 reqId;
        uint256 dpId;
        address requestor;
        address dpOwner;
        ReqStatus reqStatus;
    }

    Counters.Counter private requestIdCounter;
    DPRegistar public dpRegistar;
    mapping(uint256 => ReqInfo) public reqInfo;

    event ProposeRequest(address requestor, address dpOwner, uint256 dpId, uint256 reqId);
    event AcceptRequest(address requestor, address dpOwner, uint256 dpId, uint256 reqId);
    event RejectRequest(address requestor, address dpOwner, uint256 dpId, uint256 reqId);

    constructor(DPRegistar dpRegistar_) {
        dpRegistar = dpRegistar_;
    }

    function proposeRequest(uint256 dpId) external {
        if (!dpRegistar.isNormal(dpId)) {
            revert InvalidDpState(dpId);
        }
        uint256 reqId = requestIdCounter.current();
        requestIdCounter.increment();
        (address dpOwner,,,,,) = dpRegistar.dpInfo(dpId);
         reqInfo[reqId] = ReqInfo(reqId, dpId, msg.sender, dpOwner, ReqStatus.Proposed);
         
        emit ProposeRequest(msg.sender, dpOwner, dpId, reqId);
    }

    function acceptRquest(uint256 reqId) external {
        ReqInfo storage reqInfo_ = reqInfo[reqId];
        if (reqInfo[reqId].reqStatus != ReqStatus.Proposed) {
            revert IllegalArgument();
        }
        uint256 dpId = reqInfo_.dpId;
        if (!dpRegistar.isNormal(dpId)) {
            revert InvalidDpState(dpId);
        }
       
        address dpOwner = reqInfo_.dpOwner;
        if (msg.sender != dpOwner) revert Unauthorized();
        reqInfo_.reqStatus = ReqStatus.Accepted;

        emit AcceptRequest(msg.sender, dpOwner, dpId, reqId);
    }

    function rejectRequest(uint256 reqId) external {
        ReqInfo storage reqInfo_ = reqInfo[reqId];
        if (reqInfo[reqId].reqStatus != ReqStatus.Proposed) {
            revert IllegalArgument();
        }
        uint256 dpId = reqInfo_.dpId;
        if (!dpRegistar.isNormal(dpId)) {
            revert InvalidDpState(dpId);
        }
       
        address dpOwner = reqInfo_.dpOwner;
        if (msg.sender != dpOwner) revert Unauthorized();
        reqInfo_.reqStatus = ReqStatus.Rejected;

        emit RejectRequest(msg.sender, dpOwner, dpId, reqId);
    }
}