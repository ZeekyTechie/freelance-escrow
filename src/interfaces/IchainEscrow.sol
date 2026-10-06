// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ProjectTypes} from "../types/ProjectTypes.sol";
import {MilestoneTypes} from "../types/MilestoneTypes.sol";

/// @title IChainEscrow
/// @notice Public API of the ChainEscrow contract (events + functions)
interface IChainEscrow {
    // ============================================
    // EVENTS
    // ============================================

    // ---------- Project ----------
    event ProjectCreated(uint256 indexed projectId, address indexed client, uint256 budget);
    event ProjectAccepted(uint256 indexed projectId, address indexed freelancer);
    event ProjectFunded(uint256 indexed projectId, uint256 amount);
    event ProjectCancelled(uint256 indexed projectId);
    event ProjectCompleted(uint256 indexed projectId);
    event RefundIssued(uint256 indexed projectId, address indexed client, uint256 amount);

    // ---------- Deadline ----------
    event DeadlineExtensionProposed(uint256 indexed projectId, address indexed proposedBy, uint256 newDeadline);
    event DeadlineExtended(uint256 indexed projectId, uint256 oldDeadline, uint256 newDeadline);

    // ---------- Milestone ----------
    event MilestoneCreated(uint256 indexed projectId, uint256 indexed milestoneId, uint256 amount);
    event MilestoneSubmitted(uint256 indexed projectId, uint256 indexed milestoneId);
    event MilestoneApproved(uint256 indexed projectId, uint256 indexed milestoneId);
    event MilestonePaid(uint256 indexed projectId, uint256 indexed milestoneId, uint256 payout, uint256 fee);

    // ---------- Disputes ----------
    event DisputeOpened(uint256 indexed projectId, uint256 indexed milestoneId, address indexed openedBy);
    event DisputeResolved(uint256 indexed projectId, uint256 indexed milestoneId, bool freelancerWon);

    // ---------- Platform ----------
    event PlatformFeesWithdrawn(address indexed owner, uint256 amount);
    // ============================================
    // PROJECT FLOW
    // ============================================

    /// @notice Client creates a new project
    /// @param title Short project title
    /// @param description Project description
    /// @param budget Total budget in wei (must equal the sum of milestones before acceptance)
    /// @param deadline Unix timestamp after which unused funds can be refunded
    /// @return projectId The new project's ID
    function createProject(
        string calldata title,
        string calldata description,
        uint256 budget,
        uint256 deadline
    ) external returns (uint256 projectId);

    /// @notice Client adds a milestone while the project is still Open
    function createMilestone(uint256 projectId, string calldata title, uint256 amount)
        external
        returns (uint256 milestoneId);

    /// @notice Freelancer accepts an Open project whose milestones fully cover the budget
    function acceptProject(uint256 projectId) external;

    /// @notice Client deposits exactly the project budget into escrow
    function fundProject(uint256 projectId) external payable;

    /// @notice Client cancels a project that has not been funded yet
    function cancelProject(uint256 projectId) external;

    // ============================================
    // MILESTONE FLOW
    // ============================================

    /// @notice Freelancer submits completed milestone work
    function submitMilestone(uint256 projectId, uint256 milestoneId) external;

    /// @notice Client approves a submitted milestone
    function approveMilestone(uint256 projectId, uint256 milestoneId) external;

    /// @notice Pays an approved milestone (client or freelancer may call)
    function payMilestone(uint256 projectId, uint256 milestoneId) external;

    /// @notice Freelancer claims payment if the client ignored a submission for REVIEW_PERIOD
    function claimMilestoneAfterReview(uint256 projectId, uint256 milestoneId) external;

    // ============================================
    // REFUNDS & DISPUTES
    // ============================================

    /// @notice Client reclaims unstarted milestone funds
    /// @dev Before the deadline only possible if no milestone was submitted.
    ///      After the deadline all Pending milestones can be refunded.
    function refundClient(uint256 projectId) external;

    /// @notice Client rejects a submitted milestone and opens a dispute
    function openDispute(uint256 projectId, uint256 milestoneId) external;

    /// @notice Arbiter (contract owner) resolves a dispute
    /// @param payFreelancer true = pay freelancer (fee applies), false = refund client
    function resolveDispute(uint256 projectId, uint256 milestoneId, bool payFreelancer) external;

    // ============================================
    // DEADLINES
    // ============================================

    /// @notice Client or freelancer proposes a later deadline for an Accepted or Funded project
    /// @dev A new proposal from either side overwrites the previous one
    function proposeDeadlineExtension(uint256 projectId, uint256 newDeadline) external;

    /// @notice The other party accepts the pending proposal, which updates the deadline
    function acceptDeadlineExtension(uint256 projectId) external;

    // ============================================
    // PLATFORM
    // ============================================

    /// @notice Owner withdraws accumulated platform fees
    function withdrawPlatformFees() external;

    // ============================================
    // VIEWS
    // ============================================

    function getProject(uint256 projectId) external view returns (ProjectTypes.Project memory);
    function getProjectCount() external view returns (uint256);
    function getEscrowBalance(uint256 projectId) external view returns (uint256);
    function getMilestone(uint256 projectId, uint256 milestoneId)
        external
        view
        returns (MilestoneTypes.Milestone memory);
    function getMilestoneCount(uint256 projectId) external view returns (uint256);
    function getPlatformBalance() external view returns (uint256);

    /// @notice True if the project is Accepted or Funded and its deadline has passed
    function isOverdue(uint256 projectId) external view returns (bool);

    /// @notice Pending extension proposal (proposer is address(0) if none)
    function getDeadlineProposal(uint256 projectId)
        external
        view
        returns (address proposer, uint256 newDeadline);
}
