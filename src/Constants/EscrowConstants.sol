// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title EscrowConstants
/// @notice Platform-wide constants
library EscrowConstants {
    /// @notice Platform fee in basis points (500 = 5%)
    uint256 internal constant PLATFORM_FEE_BPS = 500;

    /// @notice Denominator for basis point maths
    uint256 internal constant BPS_DENOMINATOR = 10_000;

    /// @notice Time the client has to review a submitted milestone
    ///         before the freelancer may claim payment
    uint256 internal constant REVIEW_PERIOD = 7 days;

    /// @notice Maximum milestones per project (keeps refund loops bounded)
    uint256 internal constant MAX_MILESTONES = 20;
}
