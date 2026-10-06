// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library MilestoneErrors {
    error MilestoneDoesNotExist();

    error MilestoneAlreadySubmitted();
    error MilestoneNotPending();
    error MilestoneNotSubmitted();
    error MilestoneNotApproved();
    error MilestoneAlreadyPaid();

    error MilestoneBudgetExceeded();
    error InvalidMilestoneAmount();
    error MilestoneCreationClosed();

    error NotProjectClient();
    error NotAssignedFreelancer();

    error MilestonesAlreadyStarted();
}