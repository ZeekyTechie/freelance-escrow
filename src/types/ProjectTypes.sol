// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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