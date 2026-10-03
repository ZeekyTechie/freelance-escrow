// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Contains all events emitted by the ChainEscrow platform
interface EscrowEvents {

    // ============================================
    // PROJECT EVENTS
    // ============================================

    // Emitted whenever a new project is created
    event ProjectCreated(
        uint256 indexed projectId,
        address indexed client,
        uint256 budget
    );

    // Emitted when a freelancer accepts a project
    event ProjectAccepted(
        uint256 indexed projectId,
        address indexed freelancer
    );

    // Emitted when project funds are deposited into escrow
    event ProjectFunded(
        uint256 indexed projectId,
        uint256 amount
    );

    // Emitted when a freelancer submits completed work
    event WorkSubmitted(
        uint256 indexed projectId,
        address indexed freelancer
    );

    // Emitted when a client approves submitted work
    event WorkApproved(
        uint256 indexed projectId,
        address indexed client
    );

    // Emitted when escrow funds are released to the freelancer
    event PaymentReleased(
        uint256 indexed projectId,
        address indexed freelancer,
        uint256 amount
    );

    // Emitted when escrow funds are refunded to the client
    event RefundIssued(
        uint256 indexed projectId,
        address indexed client,
        uint256 amount
    );

    // ============================================
    // MILESTONE EVENTS
    // ============================================

    // Emitted whenever a milestone is created
    event MilestoneCreated(
        uint256 indexed projectId,
        uint256 indexed milestoneId,
        uint256 amount
    );

    // Emitted when a freelancer submits a milestone
    event MilestoneSubmitted(
        uint256 indexed projectId,
        uint256 indexed milestoneId
    );

    // Emitted when a client approves a milestone
    event MilestoneApproved(
        uint256 indexed projectId,
        uint256 indexed milestoneId
    );

    // Emitted when milestone funds are released
    event MilestonePaid(
        uint256 indexed projectId,
        uint256 indexed milestoneId,
        uint256 amount
    );

    // ============================================
    // PLATFORM EVENTS
    // ============================================

    // Emitted when the platform owner withdraws fees
    event PlatformFeesWithdrawn(
        address indexed owner,
        uint256 amount
    );

    // ============================================
    // DISPUTE EVENTS
    // ============================================

    // Emitted when a dispute is opened
    event DisputeOpened(
        uint256 indexed disputeId,
        uint256 indexed projectId,
        uint256 indexed milestoneId
    );
}