// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MilestoneTypes
/// @notice Data structures for project milestones
library MilestoneTypes {
    /// @notice Lifecycle: Pending -> Submitted -> Approved -> Paid
    /// @dev Submitted -> Disputed -> (Paid | Cancelled) when the client rejects the work.
    ///      Pending -> Cancelled when unused funds are refunded after the deadline.
    enum MilestoneStatus {
        Pending,
        Submitted,
        Approved,
        Paid,
        Disputed,
        Cancelled
    }

    struct Milestone {
        uint256 id;
        string title;
        uint256 amount;
        MilestoneStatus status;
        uint256 submittedAt;
    }
}
