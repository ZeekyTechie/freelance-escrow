// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {ProjectTypes} from "./types/ProjectTypes.sol";
import {EscrowErrors} from "./errors/EscrowErrors.sol";  
import {IChainEscrow} from "./interfaces/IChainEscrow.sol";
import {MilestoneTypes} from "./types/MilestoneTypes.sol";
import {MilestoneErrors} from "./errors/MilestoneErrors.sol";
import {EscrowConstants} from "./constants/EscrowConstants.sol";
// import {EscrowEvents} from "./events/EscrowEvents.sol";  // NOt use, so it's useless importing it here, I added it inside the Interfaces

import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
contract ChainEscrow is IChainEscrow, ReentrancyGuard {

    // ============================================
    // STATE VARIABLES
    // =========================

    uint256 private s_projectCounter; // Generates unique IDs so every project
    address private s_owner;     // Platform owner
    mapping(uint256 => ProjectTypes.Project) private s_projects;
    mapping(uint256 => uint256) private s_projectFunds; // Tracks how much ETH has been deposited for each project
    mapping(uint256 =>
        mapping(uint256 => MilestoneTypes.Milestone)
    ) private s_milestones; // Stores milestones for each project
    mapping(uint256 => uint256) private s_milestoneCounter; // Generates unique milestone IDs
    mapping(uint256 => uint256) private s_totalMilestoneAmount; // Tracks the total value of milestones created for each project
    mapping(uint256 => uint256) private s_paidMilestoneCount;
    uint256 private s_platformBalance;  // // Stores fees collected by the platform

    // ============================================
    // CONSTRUCTOR
    // ===================
    constructor() {
        s_owner = msg.sender;
    }

    // ============================================
    // PROJECT MANAGEMENT
    // =========================

    // Allows a client to create a new freelance project
    function createProject(
        string memory _title,
        string memory _description,
        uint256 _budget,
        uint256 _deadline
    ) public override {

        s_projectCounter++; // Generate a new unique project ID

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
        emit ProjectCreated(s_projectCounter, msg.sender, _budget);
    }

        // Allows the client to deposit funds into escrow
    function fundProject( uint256 _projectId) public payable override {

        ProjectTypes.Project storage project = s_projects[_projectId];

        // Ensure project exists
        if (project.id == 0) revert EscrowErrors.ProjectDoesNotExist();

        if (msg.sender != project.client) revert EscrowErrors.NotProjectClient(); // Ensure only the client can fund the project

        if (project.status != ProjectTypes.ProjectStatus.Open) revert EscrowErrors.InvalidStatus(); // Ensure freelancer has already accepted

        if (msg.value != project.budget) revert EscrowErrors.IncorrectFundingAmount();  // Ensure correct amount of ETH is sent

        // Store escrow balance
        s_projectFunds[_projectId] = msg.value;

        project.status = ProjectTypes.ProjectStatus.Funded; // Update project status

        // Notify blockchain that funds were deposited
        emit ProjectFunded(_projectId, msg.value);
    }

    // ======= Accapting Project By Freelancer
    function acceptProject(uint256 _projectId) public override {
        ProjectTypes.Project storage project = s_projects[_projectId];

        if (project.id == 0) revert EscrowErrors.ProjectDoesNotExist();
        if (project.status != ProjectTypes.ProjectStatus.Funded) {
            revert EscrowErrors.ProjectNotFunded();
        }

        project.freelancer = msg.sender;
        project.status = ProjectTypes.ProjectStatus.Accepted;

        emit ProjectAccepted(_projectId, msg.sender);
    }

    // Allows the assigned freelancer to submit completed work
    function submitWork(uint256 _projectId) public override {
        ProjectTypes.Project storage project = s_projects[_projectId];

        if (project.id == 0) revert EscrowErrors.ProjectDoesNotExist();
        if (msg.sender != project.freelancer) revert EscrowErrors.NotProjectFreelancer();
        if (project.status != ProjectTypes.ProjectStatus.Accepted) revert EscrowErrors.InvalidStatus();

        project.status = ProjectTypes.ProjectStatus.Submitted; // moving the project to submitted state

        emit WorkSubmitted(_projectId, msg.sender); // record submission on-chain
    }

    // Allows the client to approve submitted work
    function approveWork(uint256 _projectId) public override {
        ProjectTypes.Project storage project = s_projects[_projectId];

        if (project.id == 0) revert EscrowErrors.ProjectDoesNotExist();         // Ensure project exists
        if (msg.sender != project.client) revert EscrowErrors.NotProjectClient();     // Ensure only the client can approve work
        if (project.status != ProjectTypes.ProjectStatus.Submitted) revert EscrowErrors.ProjectNotSubmitted();   // Ensure work has been submitted

        project.status = ProjectTypes.ProjectStatus.Completed;   // Move project into completed state

        emit WorkApproved(_projectId, msg.sender);   // record approval on-chain
    }

    // Releases escrow funds to the freelancer
    function releasePayment(uint256 _projectId) public override nonReentrant {
        ProjectTypes.Project storage project = s_projects[_projectId];

        if (project.id == 0) revert EscrowErrors.ProjectDoesNotExist();
        if (msg.sender != project.client) revert EscrowErrors.NotProjectClient();   // Ensure only the client can release payment
        if (project.status != ProjectTypes.ProjectStatus.Completed) revert EscrowErrors.ProjectNotCompleted();  // Ensure project has been approved
        if (project.freelancer == address(0)) revert EscrowErrors.NotProjectFreelancer();

        uint256 paymentAmount = s_projectFunds[_projectId];  // Get escrow amount
        if (paymentAmount == 0) revert EscrowErrors.NoFundsAvailable();  // if amount == 0, error

        s_projectFunds[_projectId] = 0; // clear escrow balance before sending ETH

        (bool success, ) = payable(project.freelancer).call{value: paymentAmount}("");  // Send ETH to freelancer
        if (!success) revert EscrowErrors.TransferFailed();  // If transfer failed

        emit PaymentReleased(_projectId, project.freelancer, paymentAmount);
    }


    // Allows the client to reclaim escrow funds if work has not been submitted yet
    function refundClient(uint256 _projectId) public override nonReentrant {
        ProjectTypes.Project storage project = s_projects[_projectId];

        if (project.id == 0) revert EscrowErrors.ProjectDoesNotExist();
        if (msg.sender != project.client) revert EscrowErrors.NotProjectClient(); //  only the client can request a refund

        // if (project.status != ProjectTypes.ProjectStatus.Funded) revert EscrowErrors.InvalidStatus();  // refund only allowed while project is funded e.i refunds only work before the freelancer accepts. But what if the freelancer accepted, then disappeared?. So i think we should ad a deadline based refund path

        // refund allowed if:
        //   - project is Funded (freelancer never accepted), OR
        //   - project is Accepted but deadline has passed
        bool canRefundImmediately = project.status == ProjectTypes.ProjectStatus.Funded;
        bool canRefundAfterDeadline = 
            project.status == ProjectTypes.ProjectStatus.Accepted && 
            block.timestamp > project.deadline;

        if (!canRefundImmediately && !canRefundAfterDeadline) {
            revert EscrowErrors.InvalidStatus();
        }


        uint256 refundAmount = s_projectFunds[_projectId];
        if (refundAmount == 0) revert EscrowErrors.NoFundsAvailable();

        s_projectFunds[_projectId] = 0;  // clear escrow balance first
        project.status = ProjectTypes.ProjectStatus.Cancelled;  // mark project as cancelled

        (bool success, ) = payable(project.client).call{value: refundAmount}(""); // Return ETH to client
        if (!success) revert EscrowErrors.TransferFailed();

        emit RefundIssued(_projectId, project.client, refundAmount);
    }


        // ============================================
        // MILESTONE FUNCTIONS
        // =========================

    // Allows the project client to create milestones
    function createMilestone(uint256 _projectId, string memory _title, uint256 _amount) public override {
        ProjectTypes.Project storage project = s_projects[_projectId];   

        if (project.id == 0) revert EscrowErrors.ProjectDoesNotExist(); // Ensure project exists
        if (msg.sender != project.client) revert EscrowErrors.NotProjectClient();  // Ensure only project creator can add milestones

        if (s_totalMilestoneAmount[_projectId] + _amount > project.budget) { // Ensure milestone total does not exceed project budget
            revert MilestoneErrors.MilestoneBudgetExceeded();
        }

        s_milestoneCounter[_projectId]++;  // Increment milestone counter for this project
        uint256 milestoneId = s_milestoneCounter[_projectId];

        // Store milestone
        s_milestones[_projectId][milestoneId] = MilestoneTypes.Milestone({
            id: milestoneId,
            title: _title,
            amount: _amount,
            status: MilestoneTypes.MilestoneStatus.Pending
        });

        s_totalMilestoneAmount[_projectId] += _amount;  // Update total milestone allocation

        emit MilestoneCreated(_projectId, milestoneId, _amount);
    }

    // Allows the assigned freelancer to submit a milestone
    function submitMilestone(uint256 _projectId, uint256 _milestoneId) public override {
        ProjectTypes.Project storage project = s_projects[_projectId];
        MilestoneTypes.Milestone storage milestone = s_milestones[_projectId][_milestoneId];

        if (milestone.id == 0) revert MilestoneErrors.MilestoneDoesNotExist();   // Ensure milestone exists
        if (msg.sender != project.freelancer) revert MilestoneErrors.NotAssignedFreelancer();  // ensure only assigned freelancer can submit

        // Milestone must still be pending
        if (milestone.status != MilestoneTypes.MilestoneStatus.Pending) {
            revert MilestoneErrors.MilestoneNotPending();
        }

        milestone.status = MilestoneTypes.MilestoneStatus.Submitted;  // Update milestone status
        emit MilestoneSubmitted(_projectId, _milestoneId);
    }


    // Allows the client to approve a submitted milestone
    function approveMilestone(uint256 _projectId, uint256 _milestoneId) public override {
        ProjectTypes.Project storage project = s_projects[_projectId];
        MilestoneTypes.Milestone storage milestone = s_milestones[_projectId][_milestoneId];

        if (milestone.id == 0) revert MilestoneErrors.MilestoneDoesNotExist(); // ensure milestone exists

        if (msg.sender != project.client) revert MilestoneErrors.NotProjectClient();  // ensure only project client can approve

        if (milestone.status != MilestoneTypes.MilestoneStatus.Submitted) {           // milestone must be submitted first
            revert MilestoneErrors.MilestoneNotSubmitted();
        }

        milestone.status = MilestoneTypes.MilestoneStatus.Approved;   // update status
        emit MilestoneApproved(_projectId, _milestoneId);
    }


    // ===== Releases payment for an approved milestone
    function payMilestone(uint256 _projectId, uint256 _milestoneId) public override nonReentrant {
        ProjectTypes.Project storage project = s_projects[_projectId];
        MilestoneTypes.Milestone storage milestone = s_milestones[_projectId][_milestoneId];

        if (milestone.id == 0) revert MilestoneErrors.MilestoneDoesNotExist();
        if (msg.sender != project.client) revert MilestoneErrors.NotProjectClient();  // only the client can authorize payment

        if (milestone.status != MilestoneTypes.MilestoneStatus.Approved) {  // milestone must be approved
            revert MilestoneErrors.MilestoneNotSubmitted();
        }

        if (s_projectFunds[_projectId] < milestone.amount) revert EscrowErrors.NoFundsAvailable();   // ensure that project has enough escrowed funds
        if (project.freelancer == address(0)) revert EscrowErrors.NotProjectFreelancer();

        uint256 platformFee = (milestone.amount * EscrowConstants.PLATFORM_FEE) / 100;   // calculate platform fee

        uint256 freelancerPayment = milestone.amount - platformFee;  // calculate freelancer payout

        s_projectFunds[_projectId] -= milestone.amount;      // deduct milestone amount from escrow
        s_platformBalance += platformFee;          // Store platform fee

        milestone.status = MilestoneTypes.MilestoneStatus.Paid;   // mark milestone as paid
        s_paidMilestoneCount[_projectId]++;

        (bool success, ) = payable(project.freelancer).call{value: freelancerPayment}("");  // send freelancer's share
        if (!success) revert EscrowErrors.TransferFailed();

        // the project needs to auto complete when all milestones has been paid
        if (s_paidMilestoneCount[_projectId] == s_milestoneCounter[_projectId]) {
            project.status = ProjectTypes.ProjectStatus.Completed;
        }

        emit MilestonePaid(_projectId, _milestoneId, milestone.amount);
    }



    // ===================================
    // PLATFORM
    // =========================

    function withdrawPlatformFees() public override nonReentrant {
        if (msg.sender != s_owner) revert EscrowErrors.OnlyOwner();

        uint256 amount = s_platformBalance;
        if (amount == 0) revert EscrowErrors.NoFeesAvailable();

        s_platformBalance = 0;

        (bool success, ) = payable(s_owner).call{value: amount}("");
        if (!success) revert EscrowErrors.TransferFailed();

        emit PlatformFeesWithdrawn(s_owner, amount);
    }


    // ===================================
    // VIEWS
    // =========================

    // Returns details of a specific project
    function getProject(uint256 _projectId) public view override returns (ProjectTypes.Project memory){
        return s_projects[_projectId];
    }

    // Returns the amount of escrowed funds for a project
    function getProjectFunds(uint256 _projectId) public view override returns (uint256){
        return s_projectFunds[_projectId];
    }

    // returns the ETH currently held in escrow for a project
    function getEscrowBalance(uint256 _projectId) public view override returns (uint256) {
    return s_projectFunds[_projectId];
    }

    // returns the current project counter
    function getProjectCount() public view override returns (uint256) {
        return s_projectCounter;
    }

    // Returns details of a milestone
    // Each project can contain multiple milestones
    // The first key is the project ID
    // The second key is the milestone ID
    function getMilestone(uint256 _projectId, uint256 _milestoneId)
        public view override returns (MilestoneTypes.Milestone memory)
    {
        return s_milestones[_projectId][_milestoneId];
    }

    // returns the number of milestones in a project
    function getMilestoneCount(uint256 _projectId) public view override returns (uint256) {
        return s_milestoneCounter[_projectId];
    }


    // Returns the total fees collected by the platform
    function getPlatformBalance() public view override returns (uint256) {
        return s_platformBalance;
    }

    // returns owner of the project
    function getOwner() public view override returns (address) {
        return s_owner;
    }

}