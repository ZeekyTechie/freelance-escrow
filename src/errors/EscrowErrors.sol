// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
