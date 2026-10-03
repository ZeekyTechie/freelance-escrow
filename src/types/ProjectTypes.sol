// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

<<<<<<< HEAD
/// @title ProjectTypes
/// @notice The shared data types present in our ChainEscrow contract project

library ProjectTypes {
    // Represents the different stages a project can be in
    enum ProjectStatus {
        Open,            // Created n waiting for a freelancer
        Funded,          // Reserved for funding later
        Accepted,        // Freelancer has accepted
        Submitted,       // Freelancer submitted work, awaiting for the client approval
        Completed,       // Client approved and funds released
        Cancelled        // Cancelled by client or refunded
    }

    /// @notice Stores all important information about a freelance project
=======
//Library containing all project-related data structures.
library ProjectTypes {

    // Represents the different stages a project can be in
    enum ProjectStatus {
        Open,
        Funded,
        Accepted,
        Submitted,
        Completed,
        Cancelled
    }


    // Stores all important information about a freelance project
>>>>>>> d05d2db7993a92a1cf09b1d558594d9d90b4ac57
    struct Project {
        uint256 id;
        address client;
        address freelancer;
        string title;
        string description;
        uint256 budget;
        uint256 deadline;
        ProjectStatus status;
    }
}