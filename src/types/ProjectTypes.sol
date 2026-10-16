// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ProjectTypes
/// @notice Data structures for freelance projects
library ProjectTypes {
    /// @notice Lifecycle of a project: Open -> Accepted -> Funded -> Completed
    /// @dev Open and Accepted projects can be Cancelled by the client.
    ///      A Funded project becomes Cancelled only if it is fully refunded
    ///      before any milestone was started.
    enum ProjectStatus {
        Open,
        Accepted,
        Funded,
        // Submitted,
        Completed,
        Cancelled
    }

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