// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Stores all custom errors used throughout the escrow system
library EscrowErrors {

    
    error ProjectDoesNotExist();

    // Project is not available for this action
    error ProjectNotOpen();

    // Only the client who created the project can perform this action
    error NotProjectClient();

    // Only the assigned freelancer can perform this action
    error NotAssignedFreelancer();

    // Budget must be greater than zero
    error InvalidBudget();

    // Incorrect ETH amount sent
    error IncorrectFundingAmount();
}