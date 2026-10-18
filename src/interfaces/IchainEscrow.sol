// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ProjectTypes} from "../types/ProjectTypes.sol";
import {MilestoneTypes} from "../types/MilestoneTypes.sol";

/// @title IChainEscrow
/// @notice External interface for the ChainEscrow contract
interface IChainEscrow {
    // ===== Events =====
    event ProjectCreated(uint256 indexed projectId, address indexed client, uint256 budget);
    event ProjectAccepted(uint256 indexed projectId, address indexed freelancer);
    event ProjectFunded(uint256 indexed projectId, uint256 amount);
    event ProjectCancelled(uint256 indexed projectId);
    event ProjectCompleted(uint256 indexed projectId);

    event MilestoneCreated(uint256 indexed projectId, uint256 indexed milestoneId, uint256 amount);
    event MilestoneSubmitted(uint256 indexed projectId, uint256 indexed milestoneId);
    event MilestoneApproved(uint256 indexed projectId, uint256 indexed milestoneId);
    event MilestonePaid(uint256 indexed projectId, uint256 indexed milestoneId, uint256 payout, uint256 fee);

    event RefundIssued(uint256 indexed projectId, address indexed client, uint256 amount);
    event DisputeOpened(uint256 indexed projectId, uint256 indexed milestoneId, address indexed openedBy);
    event DisputeResolved(uint256 indexed projectId, uint256 indexed milestoneId, bool payFreelancer);

    event DeadlineExtensionProposed(uint256 indexed projectId, address indexed proposer, uint256 newDeadline);
    event DeadlineExtended(uint256 indexed projectId, uint256 oldDeadline, uint256 newDeadline);

    event PlatformFeesWithdrawn(address indexed owner, uint256 amount);

    // ===== Project flow =====
    function createProject(
        string calldata title,
        string calldata description,
        uint256 budget,
        uint256 deadline
    ) external returns (uint256 projectId);
    function createMilestone(uint256 projectId, string calldata title, uint256 amount)
        external
        returns (uint256 milestoneId);
    function acceptProject(uint256 projectId) external;
    function fundProject(uint256 projectId) external payable;
    function cancelProject(uint256 projectId) external;

    // ===== Milestone flow =====
    function submitMilestone(uint256 projectId, uint256 milestoneId) external;
    function approveMilestone(uint256 projectId, uint256 milestoneId) external;
    function payMilestone(uint256 projectId, uint256 milestoneId) external;
    function claimMilestoneAfterReview(uint256 projectId, uint256 milestoneId) external;

    // ===== Refunds & disputes =====
    function refundClient(uint256 projectId) external;
    function openDispute(uint256 projectId, uint256 milestoneId) external;
    function resolveDispute(uint256 projectId, uint256 milestoneId, bool payFreelancer) external;

    // ===== Deadlines =====
    function proposeDeadlineExtension(uint256 projectId, uint256 newDeadline) external;
    function acceptDeadlineExtension(uint256 projectId) external;

    // ===== Platform =====
    function withdrawPlatformFees() external;

    // ===== Views =====
    function getProject(uint256 projectId) external view returns (ProjectTypes.Project memory);
    function getProjectCount() external view returns (uint256);
    function getEscrowBalance(uint256 projectId) external view returns (uint256);
    function getMilestone(uint256 projectId, uint256 milestoneId)
        external
        view
        returns (MilestoneTypes.Milestone memory);
    function getMilestoneCount(uint256 projectId) external view returns (uint256);
    function getPlatformBalance() external view returns (uint256);
    function isOverdue(uint256 projectId) external view returns (bool);
    function getDeadlineProposal(uint256 projectId) external view returns (address proposer, uint256 newDeadline);
}