// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title EscrowErros
/// @notice To handle all custom errors for the ChainEscrow contract coz it is more gas efficient 
library EscrowErrors {
    error ProjectDoesNotExist();
    error ProjectNotOpen();
    error ProjectNotAccepted();
    error ProjectNotFunded();
    error ProjectNotSubmitted();
    error ProjectNotCompleted();
    error NotProjectClient();
    error NotProjectFreelancer();
    error DeadlineNotPassed();
    error DeadlineAlreadyPassed();
    error MustDepositBudget();
    error IncorrectFundingAmount();
    error TransferFailed();
    error InvalidStatus();
    error AlreadyFunded();
    error NoFundsAvailable();
    error OnlyOwner();
    error NoFeesAvailable();
}
