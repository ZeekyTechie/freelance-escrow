// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ProjectTypes} from "../types/ProjectTypes.sol";
import {MilestoneTypes} from "../types/MilestoneTypes.sol";

/// @notice I am expanding IChainEscrow.sol to declare all public functions which the contract exposes because this would make it a true interface and prevent any future problems 
/// Here is the updated external interface for the ChainEscrow contract

// Interface describing the public functions
// the ChainEscrow contract must provide
interface IChainEscrow {

    // =================================
    // EVENTS
    // =========================

    event ProjectCreated(uint256 indexed projectId, address indexed client, uint256 budget);
    event ProjectAccepted(uint256 indexed projectId, address indexed freelancer);
    event ProjectFunded(uint256 indexed projectId, uint256 amount);
    event WorkSubmitted(uint256 indexed projectId, address indexed freelancer);
    event WorkApproved(uint256 indexed projectId, address indexed client);
    event PaymentReleased(uint256 indexed projectId, address indexed freelancer, uint256 amount);
    event RefundIssued(uint256 indexed projectId, address indexed client, uint256 amount);

    event MilestoneCreated(uint256 indexed projectId, uint256 indexed milestoneId, uint256 amount);
    event MilestoneSubmitted(uint256 indexed projectId, uint256 indexed milestoneId);
    event MilestoneApproved(uint256 indexed projectId, uint256 indexed milestoneId);
    event MilestonePaid(uint256 indexed projectId, uint256 indexed milestoneId, uint256 amount);

    event PlatformFeesWithdrawn(address indexed owner, uint256 amount);

    // =================================
    // PROJECT FUNCTIONS
    // =========================
    // Allows a client to create a new project
    function createProject(
        string memory _title,
        string memory _description,
        uint256 _budget,
        uint256 _deadline
    ) external;

    function fundProject(uint256 _projectId) external payable;

    function acceptProject(uint256 _projectId) external;

    function submitWork(uint256 _projectId) external;

    function approveWork(uint256 _projectId) external;

    function releasePayment(uint256 _projectId) external;

    function refundClient(uint256 _projectId) external;

    // =================================
    // MILESTONE FUNCTIONS
    // =========================

    function createMilestone(
        uint256 _projectId,
        string memory _title,
        uint256 _amount
    ) external;

    function submitMilestone(uint256 _projectId, uint256 _milestoneId) external;

    function approveMilestone(uint256 _projectId, uint256 _milestoneId) external;

    function payMilestone(uint256 _projectId, uint256 _milestoneId) external;

    // =================================
    // VIEW FUNCTIONS
    // =========================

    function getProject(uint256 _projectId) external view returns (ProjectTypes.Project memory);

    function getProjectFunds(uint256 _projectId) external view returns (uint256);

    function getEscrowBalance(uint256 _projectId) external view returns (uint256);

    function getProjectCount() external view returns (uint256);

    function getMilestone(uint256 _projectId, uint256 _milestoneId) external view returns (MilestoneTypes.Milestone memory);

    function getMilestoneCount(uint256 _projectId) external view returns (uint256);

    function getPlatformBalance() external view returns (uint256);
    
    function getOwner() external view returns (address);

}