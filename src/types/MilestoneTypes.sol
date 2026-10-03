// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Contains all milestone-related data structures
library MilestoneTypes {

    // Represents the current state of a milestone
    enum MilestoneStatus {
        Pending,
        Submitted,
        Approved,
        Paid
    }

    // Stores information about a project milestone
    struct Milestone {
        uint256 id;
        string title;
        uint256 amount;
        MilestoneStatus status;
    }
}