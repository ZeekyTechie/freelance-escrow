// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ProjectTypes} from "./types/ProjectTypes.sol";
import {EscrowErrors} from "./errors/EscrowErrors.sol";
import {IChainEscrow} from "./interfaces/IChainEscrow.sol";

contract ChainEscrow is IChainEscrow {

    // ============================================
    // STATE VARIABLES
    // ============================================

    // Generates unique IDs so every project
    // can be identified and retrieved later
    uint256 private s_projectCounter;

    // Stores projects using their ID as the key
    mapping(uint256 => ProjectTypes.Project)
        private s_projects;

    // Tracks how much ETH has been deposited for each project
    mapping(uint256 => uint256)
        private s_projectFunds;

    // ============================================
    // EVENTS
    // ============================================

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

    // Emitted when project funds are deposited into escrow
    event ProjectFunded(
        uint256 indexed projectId,
        uint256 amount
);
    // ============================================
    // PROJECT MANAGEMENT
    // ============================================

    // Allows a client to create a new freelance project
    function createProject(
        string memory _title,
        string memory _description,
        uint256 _budget,
        uint256 _deadline
    ) public override {

        // Generate a new unique project ID
        s_projectCounter++;

        // Store project details on-chain
        s_projects[s_projectCounter] = ProjectTypes.Project({
            id: s_projectCounter,
            client: msg.sender,
            freelancer: address(0),
            title: _title,
            description: _description,
            budget: _budget,
            deadline: _deadline,
            status: ProjectTypes.ProjectStatus.Open
        });

        // Notify the blockchain that a project was created
        emit ProjectCreated(
            s_projectCounter,
            msg.sender,
            _budget
        );
    }

    // Returns details of a specific project
    function getProject(
        uint256 _projectId
    )
        public
        view
        returns (ProjectTypes.Project memory)
    {
        return s_projects[_projectId];
    }

// Returns the amount of escrowed funds for a project
function getProjectFunds(
    uint256 _projectId
)
    public
    view
    returns (uint256)
{
    return s_projectFunds[_projectId];
}

    // Allows a freelancer to accept an available project
    function acceptProject(
        uint256 _projectId
    ) public {

        ProjectTypes.Project storage project =
            s_projects[_projectId];

        // Ensure project exists
        require(
            project.id != 0,
            "Project does not exist"
        );

        // Ensure project is still open
        require(
            project.status ==
                ProjectTypes.ProjectStatus.Open,
            "Project is not open"
        );

        // Assign freelancer to project
        project.freelancer = msg.sender;

        // Move project into Accepted state
        project.status =
            ProjectTypes.ProjectStatus.Accepted;

        // Record acceptance on-chain
        emit ProjectAccepted(
            _projectId,
            msg.sender
        );
    }

    // Allows the client to deposit funds into escrow
function fundProject(
    uint256 _projectId
) public payable {

    ProjectTypes.Project storage project =
        s_projects[_projectId];

    // Ensure project exists
    require(
        project.id != 0,
        "Project does not exist"
    );

    // Ensure only the client can fund the project
    require(
        msg.sender == project.client,
        "Only client can fund project"
    );

    // Ensure freelancer has already accepted
    require(
        project.status ==
            ProjectTypes.ProjectStatus.Accepted,
        "Project must be accepted first"
    );

    // Ensure correct amount of ETH is sent
    require(
        msg.value == project.budget,
        "Incorrect funding amount"
    );

    // Store escrow balance
    s_projectFunds[_projectId] = msg.value;

    // Update project status
    project.status =
        ProjectTypes.ProjectStatus.Funded;

    // Notify blockchain that funds were deposited
    emit ProjectFunded(
        _projectId,
        msg.value
    );
}
}