// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ProjectTypes} from "./types/ProjectTypes.sol";
import {EscrowErrors} from "./errors/EscrowErrors.sol";
import {IChainEscrow} from "./interfaces/IChainEscrow.sol";
import {MilestoneTypes} from "./types/MilestoneTypes.sol";
import {MilestoneErrors} from "./errors/MilestoneErrors.sol";
import {EscrowConstants} from "./constants/EscrowConstants.sol";
import {EscrowEvents} from "./events/EscrowEvents.sol";

import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
contract ChainEscrow is
    IChainEscrow,
    EscrowEvents,
    ReentrancyGuard {

constructor() {
    s_owner = msg.sender;
}

    // ============================================
    // STATE VARIABLES
    // ============================================

    // Generates unique IDs so every project
    // can be identified and retrieved later
    uint256 private s_projectCounter;

    // Platform owner
address private s_owner;
    // Stores projects using their ID as the key
    mapping(uint256 => ProjectTypes.Project)
        private s_projects;

    // Tracks how much ETH has been deposited for each project
    mapping(uint256 => uint256)
        private s_projectFunds;

    // Stores milestones for each project
    mapping(
        uint256 =>
            mapping(uint256 => MilestoneTypes.Milestone)
    ) private s_milestones;

    // Generates unique milestone IDs
    mapping(uint256 => uint256)
        private s_milestoneCounter;

    // Tracks the total value of milestones created for each project
    mapping(uint256 => uint256)
        private s_totalMilestoneAmount;

    // Stores fees collected by the platform
    uint256 private s_platformBalance;

    // ============================================
    // PROJECT MANAGEMENT
    // ============================================

// Allows a client to create a new freelance project
function createProject(
    string memory _title,
    string memory _description,
    uint256 _budget,
    uint256 _deadline
) public {

    // Generate a new unique project ID
    s_projectCounter++;

    // Store the project in our mapping
    s_projects[s_projectCounter] = Project({
        id: s_projectCounter,
        client: msg.sender,
        freelancer: address(0),
        title: _title,
        description: _description,
        budget: _budget,
        deadline: _deadline,
        status: ProjectStatus.Open
    });

    // Notify the blockchain that a project was created
emit ProjectCreated(
    s_projectCounter,
    msg.sender,
    _budget
);

}

// Returns the details of a specific project
function getProject(
    uint256 _projectId
)
    public
    view
    returns (Project memory)
{
    return s_projects[_projectId];
}

// Emitted whenever a new project is created
event ProjectCreated(
    uint256 indexed projectId,
    address indexed client,
    uint256 budget
);



// Emitted when a freelancer accepts a project
event ProjectAccepted(
    uint256 indexed projectId,
    address indexed freelancer
);

// Allows a freelancer to accept an available project
function acceptProject(
    uint256 _projectId
) public {

    Project storage project =
        s_projects[_projectId];

    // Ensure the project exists
    require(
        project.id != 0,
        "Project does not exist"
    );

    // Ensure the project is still open
    require(
        project.status == ProjectStatus.Open,
        "Project is not open"
    );

    // Assign the freelancer
    project.freelancer = msg.sender;

    // Update project status
    project.status = ProjectStatus.Accepted;

    // Record acceptance on the blockchain
    emit ProjectAccepted(
        _projectId,
        msg.sender
    );
}
}