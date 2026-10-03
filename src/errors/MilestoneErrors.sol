// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Stores milestone-specific custom errors
library MilestoneErrors {

    error MilestoneDoesNotExist();

    error NotProjectClient();

    error NotAssignedFreelancer();

    error MilestoneAlreadySubmitted();

    error MilestoneNotPending();

    error MilestoneNotSubmitted();

    error MilestoneAlreadyPaid();

    error MilestoneBudgetExceeded();
}