// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ProjectTypes} from "./types/ProjectTypes.sol";
import {EscrowErrors} from "./errors/EscrowErrors.sol";
import {IChainEscrow} from "./interfaces/IChainEscrow.sol";

contract ChainEscrow {
    // ==============================================
    //                            STATE
    // ===================================================

    uint256 private s_projectCounter;
    mapping(uint256 => ProjectTypes.Project) private s_projects;


    // =================================================
    //                         CONSTRUCTOR
    // =========================================

    constructor() {
        // Nothing to initialize for now but let us note that counter starts at 0
    }

    // =============================================================
    //                     FUNCTIONS (Up coming)
    // ===========================================

    // Feature 2: createProject
    // Feature 3: submitWork
    // Feature 4: releasePayment
    // Feature 5: refundClient
    // Feature 6: access control + deadline
    // Feature 7: reentrancy guard
    // Feature 8: cancellation + events

}