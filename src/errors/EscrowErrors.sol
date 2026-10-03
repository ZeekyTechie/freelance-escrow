// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

<<<<<<< HEAD
/// @title EscrowErros
/// @notice To handle all custom errors for the ChainEscrow contract coz it's more gas efficient 
library EscrowErrors {
    error ProjectDoesNotExist();
    error ProjectNotOpen();
    error ProjectNotAccepted();
    error ProjectNotSubmitted();
    error NotProjectClient();
    error NotProjectFreelancer();
    error DeadlineNotPassed();
    error DeadlineAlreadyPassed();
    error MustDepositBudget();
    error TransferFailed();
    error InvalidStatus();
}
=======
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
>>>>>>> d05d2db7993a92a1cf09b1d558594d9d90b4ac57
