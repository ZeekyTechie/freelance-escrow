// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IChainEscrow} from "./interfaces/IChainEscrow.sol";
import {ProjectTypes} from "./types/ProjectTypes.sol";
import {MilestoneTypes} from "./types/MilestoneTypes.sol";
import {EscrowErrors} from "./errors/EscrowErrors.sol";
import {EscrowConstants} from "./constants/EscrowConstants.sol";

/// @title ChainEscrow
/// @notice Milestone-based freelance escrow. Every project is paid through milestones.
/// @dev Flow: createProject -> createMilestone (xN) -> acceptProject -> fundProject
///      -> submitMilestone -> approveMilestone -> payMilestone.
///      Terms are locked once the freelancer accepts.
contract ChainEscrow is IChainEscrow, Ownable2Step, ReentrancyGuard {
    // ============================================
    // STATE
    // ============================================

    uint256 private s_projectCounter;
    uint256 private s_platformBalance;

    mapping(uint256 projectId => ProjectTypes.Project) private s_projects;
    mapping(uint256 projectId => uint256) private s_projectFunds;
    mapping(uint256 projectId => mapping(uint256 milestoneId => MilestoneTypes.Milestone)) private s_milestones;
    mapping(uint256 projectId => uint256) private s_milestoneCounter;
    mapping(uint256 projectId => uint256) private s_totalMilestoneAmount;

    /// @dev Milestones that left Pending because of a submission (blocks early refunds)
    mapping(uint256 projectId => uint256) private s_startedMilestones;

    /// @dev Milestones that ended as Paid or Cancelled
    mapping(uint256 projectId => uint256) private s_settledMilestones;

    /// @dev Pending deadline extension proposal (proposer == address(0) means none)
    mapping(uint256 projectId => uint256) private s_proposedDeadline;
    mapping(uint256 projectId => address) private s_deadlineProposer;

    // ============================================
    // MODIFIERS
    // ============================================

    modifier projectExists(uint256 projectId) {
        if (s_projects[projectId].id == 0) revert EscrowErrors.ProjectDoesNotExist();
        _;
    }

    modifier onlyClient(uint256 projectId) {
        if (msg.sender != s_projects[projectId].client) revert EscrowErrors.NotProjectClient();
        _;
    }

    modifier onlyFreelancer(uint256 projectId) {
        if (msg.sender != s_projects[projectId].freelancer) revert EscrowErrors.NotAssignedFreelancer();
        _;
    }

    modifier projectOpen(uint256 projectId) {
        if (s_projects[projectId].status != ProjectTypes.ProjectStatus.Open) revert EscrowErrors.ProjectNotOpen();
        _;
    }

    modifier projectAccepted(uint256 projectId) {
        if (s_projects[projectId].status != ProjectTypes.ProjectStatus.Accepted) {
            revert EscrowErrors.ProjectNotAccepted();
        }
        _;
    }

    modifier projectFunded(uint256 projectId) {
        if (s_projects[projectId].status != ProjectTypes.ProjectStatus.Funded) revert EscrowErrors.ProjectNotFunded();
        _;
    }

    // ============================================
    // CONSTRUCTOR
    // ============================================

    constructor() Ownable(msg.sender) {}

    // ============================================
    // PROJECT FLOW
    // ============================================

    /// @inheritdoc IChainEscrow
    function createProject(
        string calldata title,
        string calldata description,
        uint256 budget,
        uint256 deadline
    ) external override returns (uint256 projectId) {
        if (budget == 0) revert EscrowErrors.InvalidBudget();
        if (deadline <= block.timestamp) revert EscrowErrors.InvalidDeadline();

        projectId = ++s_projectCounter;

        s_projects[projectId] = ProjectTypes.Project({
            id: projectId,
            client: msg.sender,
            freelancer: address(0),
            title: title,
            description: description,
            budget: budget,
            deadline: deadline,
            status: ProjectTypes.ProjectStatus.Open
        });

        emit ProjectCreated(projectId, msg.sender, budget);
    }

    /// @inheritdoc IChainEscrow
    function createMilestone(uint256 projectId, string calldata title, uint256 amount)
        external
        override
        projectExists(projectId)
        onlyClient(projectId)
        projectOpen(projectId)
        returns (uint256 milestoneId)
    {
        if (amount == 0) revert EscrowErrors.InvalidMilestoneAmount();
        if (s_milestoneCounter[projectId] >= EscrowConstants.MAX_MILESTONES) {
            revert EscrowErrors.TooManyMilestones();
        }
        if (s_totalMilestoneAmount[projectId] + amount > s_projects[projectId].budget) {
            revert EscrowErrors.MilestoneBudgetExceeded();
        }

        milestoneId = ++s_milestoneCounter[projectId];

        s_milestones[projectId][milestoneId] = MilestoneTypes.Milestone({
            id: milestoneId,
            title: title,
            amount: amount,
            status: MilestoneTypes.MilestoneStatus.Pending,
            submittedAt: 0
        });

        s_totalMilestoneAmount[projectId] += amount;

        emit MilestoneCreated(projectId, milestoneId, amount);
    }

    /// @inheritdoc IChainEscrow
    function acceptProject(uint256 projectId)
        external
        override
        projectExists(projectId)
        projectOpen(projectId)
    {
        ProjectTypes.Project storage project = s_projects[projectId];

        if (msg.sender == project.client) revert EscrowErrors.ClientCannotAcceptOwnProject();
        if (s_totalMilestoneAmount[projectId] != project.budget) {
            revert EscrowErrors.MilestonesNotFullyAllocated();
        }

        project.freelancer = msg.sender;
        project.status = ProjectTypes.ProjectStatus.Accepted;

        emit ProjectAccepted(projectId, msg.sender);
    }

    /// @inheritdoc IChainEscrow
    function fundProject(uint256 projectId)
        external
        payable
        override
        projectExists(projectId)
        onlyClient(projectId)
        projectAccepted(projectId)
    {
        ProjectTypes.Project storage project = s_projects[projectId];

        if (msg.value != project.budget) revert EscrowErrors.IncorrectFundingAmount();

        s_projectFunds[projectId] = msg.value;
        project.status = ProjectTypes.ProjectStatus.Funded;

        emit ProjectFunded(projectId, msg.value);
    }

    /// @inheritdoc IChainEscrow
    function cancelProject(uint256 projectId) external override projectExists(projectId) onlyClient(projectId) {
        ProjectTypes.Project storage project = s_projects[projectId];

        if (
            project.status != ProjectTypes.ProjectStatus.Open
                && project.status != ProjectTypes.ProjectStatus.Accepted
        ) {
            revert EscrowErrors.ProjectNotCancellable();
        }

        project.status = ProjectTypes.ProjectStatus.Cancelled;

        emit ProjectCancelled(projectId);
    }

    // ============================================
    // MILESTONE FLOW
    // ============================================

    /// @inheritdoc IChainEscrow
    function submitMilestone(uint256 projectId, uint256 milestoneId)
        external
        override
        projectExists(projectId)
        onlyFreelancer(projectId)
        projectFunded(projectId)
    {
        MilestoneTypes.Milestone storage milestone = _getMilestone(projectId, milestoneId);

        if (milestone.status != MilestoneTypes.MilestoneStatus.Pending) {
            revert EscrowErrors.MilestoneNotPending();
        }

        milestone.status = MilestoneTypes.MilestoneStatus.Submitted;
        milestone.submittedAt = block.timestamp;
        s_startedMilestones[projectId]++;

        emit MilestoneSubmitted(projectId, milestoneId);
    }

    /// @inheritdoc IChainEscrow
    function approveMilestone(uint256 projectId, uint256 milestoneId)
        external
        override
        projectExists(projectId)
        onlyClient(projectId)
        projectFunded(projectId)
    {
        MilestoneTypes.Milestone storage milestone = _getMilestone(projectId, milestoneId);

        if (milestone.status != MilestoneTypes.MilestoneStatus.Submitted) {
            revert EscrowErrors.MilestoneNotSubmitted();
        }

        milestone.status = MilestoneTypes.MilestoneStatus.Approved;

        emit MilestoneApproved(projectId, milestoneId);
    }

    /// @inheritdoc IChainEscrow
    function payMilestone(uint256 projectId, uint256 milestoneId)
        external
        override
        nonReentrant
        projectExists(projectId)
        projectFunded(projectId)
    {
        ProjectTypes.Project storage project = s_projects[projectId];

        // Either side may trigger payment, so an approved milestone can never be held hostage
        if (msg.sender != project.client && msg.sender != project.freelancer) {
            revert EscrowErrors.NotProjectParticipant();
        }

        MilestoneTypes.Milestone storage milestone = _getMilestone(projectId, milestoneId);

        if (milestone.status != MilestoneTypes.MilestoneStatus.Approved) {
            revert EscrowErrors.MilestoneNotApproved();
        }

        _payFreelancer(projectId, milestoneId);
    }

    /// @inheritdoc IChainEscrow
    function claimMilestoneAfterReview(uint256 projectId, uint256 milestoneId)
        external
        override
        nonReentrant
        projectExists(projectId)
        onlyFreelancer(projectId)
        projectFunded(projectId)
    {
        MilestoneTypes.Milestone storage milestone = _getMilestone(projectId, milestoneId);

        if (milestone.status != MilestoneTypes.MilestoneStatus.Submitted) {
            revert EscrowErrors.MilestoneNotSubmitted();
        }
        if (block.timestamp < milestone.submittedAt + EscrowConstants.REVIEW_PERIOD) {
            revert EscrowErrors.ReviewPeriodNotElapsed();
        }

        emit MilestoneApproved(projectId, milestoneId);
        _payFreelancer(projectId, milestoneId);
    }

    // ============================================
    // REFUNDS & DISPUTES
    // ============================================

    /// @inheritdoc IChainEscrow
    function refundClient(uint256 projectId)
        external
        override
        nonReentrant
        projectExists(projectId)
        onlyClient(projectId)
        projectFunded(projectId)
    {
        // Before the deadline, refunds are only possible if no work was ever submitted.
        if (block.timestamp <= s_projects[projectId].deadline && s_startedMilestones[projectId] != 0) {
            revert EscrowErrors.RefundNotAvailable();
        }

        uint256 count = s_milestoneCounter[projectId];
        uint256 refundAmount = 0;
        uint256 cancelled = 0;

        for (uint256 i = 1; i <= count; i++) {
            MilestoneTypes.Milestone storage milestone = s_milestones[projectId][i];
            if (milestone.status == MilestoneTypes.MilestoneStatus.Pending) {
                refundAmount += milestone.amount;
                milestone.status = MilestoneTypes.MilestoneStatus.Cancelled;
                cancelled++;
            }
        }

        if (refundAmount == 0) revert EscrowErrors.NoFundsAvailable();

        s_projectFunds[projectId] -= refundAmount;
        s_settledMilestones[projectId] += cancelled;
        _finalizeIfSettled(projectId);

        address client = s_projects[projectId].client;
        emit RefundIssued(projectId, client, refundAmount);

        _sendEth(client, refundAmount);
    }

    /// @inheritdoc IChainEscrow
    function openDispute(uint256 projectId, uint256 milestoneId)
        external
        override
        projectExists(projectId)
        onlyClient(projectId)
        projectFunded(projectId)
    {
        MilestoneTypes.Milestone storage milestone = _getMilestone(projectId, milestoneId);

        if (milestone.status != MilestoneTypes.MilestoneStatus.Submitted) {
            revert EscrowErrors.MilestoneNotSubmitted();
        }

        milestone.status = MilestoneTypes.MilestoneStatus.Disputed;

        emit DisputeOpened(projectId, milestoneId, msg.sender);
    }

    /// @inheritdoc IChainEscrow
    function resolveDispute(uint256 projectId, uint256 milestoneId, bool payFreelancer)
        external
        override
        nonReentrant
        onlyOwner
        projectExists(projectId)
        projectFunded(projectId)
    {
        MilestoneTypes.Milestone storage milestone = _getMilestone(projectId, milestoneId);

        if (milestone.status != MilestoneTypes.MilestoneStatus.Disputed) {
            revert EscrowErrors.MilestoneNotDisputed();
        }

        emit DisputeResolved(projectId, milestoneId, payFreelancer);

        if (payFreelancer) {
            _payFreelancer(projectId, milestoneId);
        } else {
            uint256 amount = milestone.amount;

            s_projectFunds[projectId] -= amount;
            milestone.status = MilestoneTypes.MilestoneStatus.Cancelled;
            s_settledMilestones[projectId]++;
            _finalizeIfSettled(projectId);

            _sendEth(s_projects[projectId].client, amount);
        }
    }

    // ============================================
    // DEADLINE MANAGEMENT
    // ============================================

    /// @inheritdoc IChainEscrow
    function proposeDeadlineExtension(uint256 projectId, uint256 newDeadline)
        external
        override
        projectExists(projectId)
    {
        ProjectTypes.Project storage project = s_projects[projectId];

        _requireActive(project);
        _requireParticipant(project);

        if (newDeadline <= block.timestamp) revert EscrowErrors.InvalidDeadline();
        if (newDeadline <= project.deadline) revert EscrowErrors.DeadlineNotExtended();

        s_proposedDeadline[projectId] = newDeadline;
        s_deadlineProposer[projectId] = msg.sender;

        emit DeadlineExtensionProposed(projectId, msg.sender, newDeadline);
    }

    /// @inheritdoc IChainEscrow
    function acceptDeadlineExtension(uint256 projectId) external override projectExists(projectId) {
        ProjectTypes.Project storage project = s_projects[projectId];

        _requireActive(project);
        _requireParticipant(project);

        address proposer = s_deadlineProposer[projectId];
        uint256 newDeadline = s_proposedDeadline[projectId];

        if (proposer == address(0)) revert EscrowErrors.NoPendingExtension();
        if (msg.sender == proposer) revert EscrowErrors.CannotAcceptOwnProposal();
        // A proposal that is already in the past is stale and must be re-proposed
        if (newDeadline <= block.timestamp) revert EscrowErrors.InvalidDeadline();

        uint256 oldDeadline = project.deadline;
        project.deadline = newDeadline;

        delete s_proposedDeadline[projectId];
        delete s_deadlineProposer[projectId];

        emit DeadlineExtended(projectId, oldDeadline, newDeadline);
    }

    // ============================================
    // PLATFORM
    // ============================================

    /// @inheritdoc IChainEscrow
    function withdrawPlatformFees() external override nonReentrant onlyOwner {
        uint256 amount = s_platformBalance;
        if (amount == 0) revert EscrowErrors.NoFeesAvailable();

        s_platformBalance = 0;

        emit PlatformFeesWithdrawn(owner(), amount);

        _sendEth(owner(), amount);
    }

    /// @notice Disabled. Renouncing ownership would permanently lock dispute
    ///         resolution and platform fee withdrawals.
    function renounceOwnership() public pure override {
        revert EscrowErrors.RenounceOwnershipDisabled();
    }

    // ============================================
    // VIEWS
    // ============================================

    /// @inheritdoc IChainEscrow
    function getProject(uint256 projectId) external view override returns (ProjectTypes.Project memory) {
        return s_projects[projectId];
    }

    /// @inheritdoc IChainEscrow
    function getProjectCount() external view override returns (uint256) {
        return s_projectCounter;
    }

    /// @inheritdoc IChainEscrow
    function getEscrowBalance(uint256 projectId) external view override returns (uint256) {
        return s_projectFunds[projectId];
    }

    /// @inheritdoc IChainEscrow
    function getMilestone(uint256 projectId, uint256 milestoneId)
        external
        view
        override
        returns (MilestoneTypes.Milestone memory)
    {
        return s_milestones[projectId][milestoneId];
    }

    /// @inheritdoc IChainEscrow
    function getMilestoneCount(uint256 projectId) external view override returns (uint256) {
        return s_milestoneCounter[projectId];
    }

    /// @inheritdoc IChainEscrow
    function getPlatformBalance() external view override returns (uint256) {
        return s_platformBalance;
    }

    /// @inheritdoc IChainEscrow
    function isOverdue(uint256 projectId) external view override returns (bool) {
        ProjectTypes.Project storage project = s_projects[projectId];

        bool active = project.status == ProjectTypes.ProjectStatus.Accepted
            || project.status == ProjectTypes.ProjectStatus.Funded;

        return active && block.timestamp > project.deadline;
    }

    /// @inheritdoc IChainEscrow
    function getDeadlineProposal(uint256 projectId)
        external
        view
        override
        returns (address proposer, uint256 newDeadline)
    {
        return (s_deadlineProposer[projectId], s_proposedDeadline[projectId]);
    }

    // ============================================
    // INTERNAL HELPERS
    // ============================================

    /// @dev Reverts unless the project is Accepted or Funded
    function _requireActive(ProjectTypes.Project storage project) private view {
        if (
            project.status != ProjectTypes.ProjectStatus.Accepted
                && project.status != ProjectTypes.ProjectStatus.Funded
        ) {
            revert EscrowErrors.ProjectNotActive();
        }
    }

    /// @dev Reverts unless the caller is the client or the assigned freelancer
    function _requireParticipant(ProjectTypes.Project storage project) private view {
        if (msg.sender != project.client && msg.sender != project.freelancer) {
            revert EscrowErrors.NotProjectParticipant();
        }
    }

    /// @dev Loads a milestone and reverts if it does not exist
    function _getMilestone(uint256 projectId, uint256 milestoneId)
        private
        view
        returns (MilestoneTypes.Milestone storage milestone)
    {
        milestone = s_milestones[projectId][milestoneId];
        if (milestone.id == 0) revert EscrowErrors.MilestoneDoesNotExist();
    }

    /// @dev Pays the freelancer for a milestone, taking the platform fee.
    ///      All state is updated before the ETH transfer (checks-effects-interactions).
    function _payFreelancer(uint256 projectId, uint256 milestoneId) private {
        MilestoneTypes.Milestone storage milestone = s_milestones[projectId][milestoneId];

        uint256 amount = milestone.amount;
        uint256 fee = (amount * EscrowConstants.PLATFORM_FEE_BPS) / EscrowConstants.BPS_DENOMINATOR;
        uint256 payout = amount - fee;

        s_projectFunds[projectId] -= amount;
        s_platformBalance += fee;
        milestone.status = MilestoneTypes.MilestoneStatus.Paid;
        s_settledMilestones[projectId]++;

        _finalizeIfSettled(projectId);

        emit MilestonePaid(projectId, milestoneId, payout, fee);

        _sendEth(s_projects[projectId].freelancer, payout);
    }

    /// @dev Closes the project once every milestone is Paid or Cancelled
    function _finalizeIfSettled(uint256 projectId) private {
        if (s_settledMilestones[projectId] != s_milestoneCounter[projectId]) return;

        ProjectTypes.Project storage project = s_projects[projectId];

        if (s_startedMilestones[projectId] == 0) {
            project.status = ProjectTypes.ProjectStatus.Cancelled;
            emit ProjectCancelled(projectId);
        } else {
            project.status = ProjectTypes.ProjectStatus.Completed;
            emit ProjectCompleted(projectId);
        }
    }

    function _sendEth(address to, uint256 amount) private {
        (bool success,) = payable(to).call{value: amount}("");
        if (!success) revert EscrowErrors.TransferFailed();
    }
}
