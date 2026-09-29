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

    // Emitted when a freelancer submits completed work
    event WorkSubmitted(
        uint256 indexed projectId,
        address indexed freelancer
);

    // Emitted when a client approves submitted work
    event WorkApproved(
        uint256 indexed projectId,
        address indexed client
);

    // Emitted when escrow funds are released to the freelancer
event PaymentReleased(
    uint256 indexed projectId,
    address indexed freelancer,
    uint256 amount
);

// Emitted when escrow funds are refunded to the client
event RefundIssued(
    uint256 indexed projectId,
    address indexed client,
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

    // Allows the assigned freelancer to submit completed work
function submitWork(
    uint256 _projectId
) public {

    ProjectTypes.Project storage project =
        s_projects[_projectId];

    // Ensure project exists
    require(
        project.id != 0,
        "Project does not exist"
    );

    // Ensure only assigned freelancer can submit work
    require(
        msg.sender == project.freelancer,
        "Only assigned freelancer can submit work"
    );

    // Ensure project has been funded
    require(
        project.status ==
            ProjectTypes.ProjectStatus.Funded,
        "Project must be funded first"
    );

    // Move project to submitted state
    project.status =
        ProjectTypes.ProjectStatus.Submitted;

    // Record submission on-chain
    emit WorkSubmitted(
        _projectId,
        msg.sender
    );
}

// Allows the client to approve submitted work
function approveWork(
    uint256 _projectId
) public {

    ProjectTypes.Project storage project =
        s_projects[_projectId];

    // Ensure project exists
    require(
        project.id != 0,
        "Project does not exist"
    );

    // Ensure only the client can approve work
    require(
        msg.sender == project.client,
        "Only client can approve work"
    );

    // Ensure work has been submitted
    require(
        project.status ==
            ProjectTypes.ProjectStatus.Submitted,
        "Work has not been submitted"
    );

    // Move project into completed state
    project.status =
        ProjectTypes.ProjectStatus.Completed;

    // Record approval on-chain
    emit WorkApproved(
        _projectId,
        msg.sender
    );
}

// Returns the current project counter
function getProjectCount()
    public
    view
    returns (uint256)
{
    return s_projectCounter;
}

// Returns the ETH currently held in escrow for a project
function getEscrowBalance(
    uint256 _projectId
)
    public
    view
    returns (uint256)
{
    return s_projectFunds[_projectId];
}


// Releases escrow funds to the freelancer
function releasePayment(
    uint256 _projectId
) public {

    ProjectTypes.Project storage project =
        s_projects[_projectId];

    // Ensure project exists
    require(
        project.id != 0,
        "Project does not exist"
    );

    // Ensure only the client can release payment
    require(
        msg.sender == project.client,
        "Only client can release payment"
    );

    // Ensure project has been approved
    require(
        project.status ==
            ProjectTypes.ProjectStatus.Completed,
        "Project not approved"
    );

    // Get escrow amount
    uint256 paymentAmount =
        s_projectFunds[_projectId];

    // Prevent double payment
    require(
        paymentAmount > 0,
        "No funds available"
    );

    // Clear escrow balance before sending ETH
    s_projectFunds[_projectId] = 0;

    // Send ETH to freelancer
    (bool success, ) =
        payable(project.freelancer).call{
            value: paymentAmount
        }("");

    require(
        success,
        "Payment transfer failed"
    );

    emit PaymentReleased(
        _projectId,
        project.freelancer,
        paymentAmount
    );
}

// Allows the client to reclaim escrow funds
// if work has not been submitted yet
function refundClient(
    uint256 _projectId
) public {

    ProjectTypes.Project storage project =
        s_projects[_projectId];

    // Ensure project exists
    require(
        project.id != 0,
        "Project does not exist"
    );

    // Only the client can request a refund
    require(
        msg.sender == project.client,
        "Only client can request refund"
    );

    // Refund only allowed while project is funded
    require(
        project.status ==
            ProjectTypes.ProjectStatus.Funded,
        "Refund not available"
    );

    uint256 refundAmount =
        s_projectFunds[_projectId];

    require(
        refundAmount > 0,
        "No funds available"
    );

    // Clear escrow balance first
    s_projectFunds[_projectId] = 0;

    // Mark project as cancelled
    project.status =
        ProjectTypes.ProjectStatus.Cancelled;

    // Return ETH to client
    (bool success, ) =
        payable(project.client).call{
            value: refundAmount
        }("");

    require(
        success,
        "Refund transfer failed"
    );

    emit RefundIssued(
        _projectId,
        project.client,
        refundAmount
    );
}
}