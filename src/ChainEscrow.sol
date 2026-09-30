// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {ProjectTypes} from "./types/ProjectTypes.sol";
import {EscrowErrors} from "./errors/EscrowErrors.sol";
import {IChainEscrow} from "./interfaces/IChainEscrow.sol";
import {MilestoneTypes} from "./types/MilestoneTypes.sol";
import {MilestoneErrors} from "./errors/MilestoneErrors.sol";
import {EscrowConstants} from "./constants/EscrowConstants.sol";

import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
contract ChainEscrow is IChainEscrow, ReentrancyGuard {

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

    // Emitted whenever a milestone is created
    event MilestoneCreated(
        uint256 indexed projectId,
        uint256 indexed milestoneId,
        uint256 amount
);

    // Emitted when a milestone is submitted by the freelancer
    event MilestoneSubmitted(
        uint256 indexed projectId,
        uint256 indexed milestoneId
);

    // Emitted when a client approves a submitted milestone
    event MilestoneApproved(
        uint256 indexed projectId,
        uint256 indexed milestoneId
);

    // Emitted when a milestone payment is released
    event MilestonePaid(
        uint256 indexed projectId,
        uint256 indexed milestoneId,
        uint256 amount
);

    event PlatformFeesWithdrawn(
    address indexed owner,
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

    // Allows the project client to create milestones
function createMilestone(
    uint256 _projectId,
    string memory _title,
    uint256 _amount
) public {

    ProjectTypes.Project storage project =
        s_projects[_projectId];

    // Ensure project exists
    require(
        project.id != 0,
        "Project does not exist"
    );

    // Ensure only project creator can add milestones
    require(
        msg.sender == project.client,
        "Only project client can create milestones"
    );

    // Ensure milestone total does not exceed project budget
    if (
        s_totalMilestoneAmount[_projectId] +
        _amount >
        project.budget
    ) {
        revert MilestoneErrors.MilestoneBudgetExceeded();
    }
    // Increment milestone counter for this project
    s_milestoneCounter[_projectId]++;

    uint256 milestoneId =
        s_milestoneCounter[_projectId];

    // Store milestone
    s_milestones[_projectId][milestoneId] =
        MilestoneTypes.Milestone({
            id: milestoneId,
            title: _title,
            amount: _amount,
            status:
                MilestoneTypes.MilestoneStatus.Pending
        });

    // Update total milestone allocation
s_totalMilestoneAmount[_projectId] +=
    _amount;

    emit MilestoneCreated(
        _projectId,
        milestoneId,
        _amount
    );
}

// Allows the assigned freelancer to submit a milestone
function submitMilestone(
    uint256 _projectId,
    uint256 _milestoneId
) public {

    ProjectTypes.Project storage project =
        s_projects[_projectId];

    MilestoneTypes.Milestone storage milestone =
        s_milestones[_projectId][_milestoneId];

    // Ensure milestone exists
    if (milestone.id == 0) {
        revert MilestoneErrors.MilestoneDoesNotExist();
    }

    // Ensure only assigned freelancer can submit
    if (msg.sender != project.freelancer) {
        revert MilestoneErrors.NotAssignedFreelancer();
    }

    // Milestone must still be pending
    if (
        milestone.status !=
        MilestoneTypes.MilestoneStatus.Pending
    ) {
        revert MilestoneErrors.MilestoneNotPending();
    }

    // Update milestone status
    milestone.status =
        MilestoneTypes.MilestoneStatus.Submitted;

    emit MilestoneSubmitted(
        _projectId,
        _milestoneId
    );
}

// Allows the client to approve a submitted milestone
function approveMilestone(
    uint256 _projectId,
    uint256 _milestoneId
) public {

    ProjectTypes.Project storage project =
        s_projects[_projectId];

    MilestoneTypes.Milestone storage milestone =
        s_milestones[_projectId][_milestoneId];

    // Ensure milestone exists
    if (milestone.id == 0) {
        revert MilestoneErrors.MilestoneDoesNotExist();
    }

    // Ensure only project client can approve
    if (msg.sender != project.client) {
        revert MilestoneErrors.NotProjectClient();
    }

    // Milestone must be submitted first
    if (
        milestone.status !=
        MilestoneTypes.MilestoneStatus.Submitted
    ) {
        revert MilestoneErrors.MilestoneNotSubmitted();
    }

    // Update status
    milestone.status =
        MilestoneTypes.MilestoneStatus.Approved;

    emit MilestoneApproved(
        _projectId,
        _milestoneId
    );
}

// Releases payment for an approved milestone
function payMilestone(
    uint256 _projectId,
    uint256 _milestoneId
) public nonReentrant {

    ProjectTypes.Project storage project =
        s_projects[_projectId];

    MilestoneTypes.Milestone storage milestone =
        s_milestones[_projectId][_milestoneId];

    // Ensure milestone exists
    if (milestone.id == 0) {
        revert MilestoneErrors.MilestoneDoesNotExist();
    }

    // Only the client can authorize payment
    if (msg.sender != project.client) {
        revert MilestoneErrors.NotProjectClient();
    }

    // Milestone must be approved
    if (
        milestone.status !=
        MilestoneTypes.MilestoneStatus.Approved
    ) {
        revert MilestoneErrors.MilestoneNotSubmitted();
    }

    // Ensure project has enough escrowed funds
    require(
        s_projectFunds[_projectId] >= milestone.amount,
        "Insufficient escrow balance"
    );

    // Calculate platform fee
uint256 platformFee =
    (milestone.amount *
        EscrowConstants.PLATFORM_FEE) / 100;

// Calculate freelancer payout
uint256 freelancerPayment =
    milestone.amount - platformFee;

// Deduct milestone amount from escrow
s_projectFunds[_projectId] -=
    milestone.amount;

// Store platform fee
s_platformBalance += platformFee;

// Mark milestone as paid
milestone.status =
    MilestoneTypes.MilestoneStatus.Paid;

// Send freelancer's share
(bool success, ) =
    payable(project.freelancer).call{
        value: freelancerPayment
    }("");

require(
    success,
    "Milestone payment failed"
);

    emit MilestonePaid(
        _projectId,
        _milestoneId,
        milestone.amount
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

// Returns the total fees collected by the platform
function getPlatformBalance()
    public
    view
    returns (uint256)
{
    return s_platformBalance;
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

//Getter Functions
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

// Returns details of a milestone
// Each project can contain multiple milestones.
// The first key is the project ID.
// The second key is the milestone ID.
function getMilestone(
    uint256 _projectId,
    uint256 _milestoneId
)
    public
    view
    returns (MilestoneTypes.Milestone memory)
{
    return
        s_milestones[
            _projectId
        ][
            _milestoneId
        ];
}

// Returns the number of milestones in a project
function getMilestoneCount(
    uint256 _projectId
)
    public
    view
    returns (uint256)
{
    return s_milestoneCounter[_projectId];
}

function getOwner()
    public
    view
    returns (address)
{
    return s_owner;
}

function withdrawPlatformFees()
    public
    nonReentrant
{
    require(
        msg.sender == s_owner,
        "Only owner can withdraw"
    );

    uint256 amount =
        s_platformBalance;

    require(
        amount > 0,
        "No fees available"
    );

    s_platformBalance = 0;

    (bool success, ) =
        payable(s_owner).call{
            value: amount
        }("");

    require(
        success,
        "Withdrawal failed"
    );

    emit PlatformFeesWithdrawn(
        s_owner,
        amount
    );
}

// Releases escrow funds to the freelancer
function releasePayment(
    uint256 _projectId
) public nonReentrant {

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
) public nonReentrant {

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