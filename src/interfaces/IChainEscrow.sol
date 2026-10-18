// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ProjectTypes} from "../types/ProjectTypes.sol";

/// @title IChainEscrow
/// @notice This is the external interface for the ChainEscrow contract

interface IChainEscrow {

    // ==== All The Events ===
    event ProjectCreated(uint256 indexed projectId, address indexed client, uint256 budget);

    event ProjectAccepted(uint256 indexed projectId, address indexed freelancer);

    event WorkSubmitted(uint256 indexed projectId, address indexed freelancer);

    event PaymentReleased(uint256 indexed projectId, address indexed freelancer, uint256 amount);

    event ProjectCancelled(uint256 indexed projectId, address indexed by);

    event ClientRefunded(uint256 indexed projectId, address indexed client, uint256 amount);

    // ===== Our Main Functions ======

    // Allows a client to create a new freelance project
    function createProject(
        string memory _title,
        string memory _description,
        uint256 _deadline
    ) external payable returns (uint256);

    function acceptProject(uint256 _projectId) external;
    function submitWork(uint256 _projectId) external;
    function releasePayment(uint256 _projectId) external;
    function refundClient(uint256 _projectId) external;
    function cancelProject(uint256 _projectId) external;


    // ===== Our View Functions ============

    // Returns the details of a specific project
    function getProject(uint256 _projectId) external view returns (ProjectTypes.Project memory);

    function getProjectCount() external view returns (uint256);

}
