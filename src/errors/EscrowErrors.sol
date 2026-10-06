// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title EscrowErrors
/// @notice All custom errors used by the escrow system
library EscrowErrors {
    // ---------- Project state ----------
    error ProjectDoesNotExist();
    error ProjectNotOpen();
    error ProjectNotAccepted();
    error ProjectNotFunded();
    error ProjectNotCancellable();

    // ---------- Project validation ----------
    error InvalidBudget();
    error InvalidDeadline();
    error IncorrectFundingAmount();
    error ClientCannotAcceptOwnProject();
    error MilestonesNotFullyAllocated();

    // ---------- Deadline ----------
    error ProjectNotActive();
    error DeadlineNotExtended();
    error NoPendingExtension();
    error CannotAcceptOwnProposal();

    // ---------- Access control ----------
    error NotProjectClient();
    error NotAssignedFreelancer();
    error NotProjectParticipant();

    // ---------- Milestone state ----------
    error MilestoneDoesNotExist();
    error MilestoneNotPending();
    error MilestoneNotSubmitted();
    error MilestoneNotApproved();
    error MilestoneNotDisputed();

    // ---------- Milestone validation ----------
    error InvalidMilestoneAmount();
    error MilestoneBudgetExceeded();
    error TooManyMilestones();
    error ReviewPeriodNotElapsed();

    // ---------- Ownership ----------
    error RenounceOwnershipDisabled();

    // ---------- Money ----------
    error RefundNotAvailable();
    error NoFundsAvailable();
    error NoFeesAvailable();
    error TransferFailed();
}