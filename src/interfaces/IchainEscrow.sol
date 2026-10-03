// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Interface describing the public functions
// the ChainEscrow contract must provide
interface IChainEscrow {

    // Allows a client to create a new project
    function createProject(
        string memory _title,
        string memory _description,
        uint256 _budget,
        uint256 _deadline
    ) external;
}