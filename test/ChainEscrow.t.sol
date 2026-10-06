// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ChainEscrow} from "../src/ChainEscrow.sol";
import {IChainEscrow} from "../src/interfaces/IChainEscrow.sol";
import {EscrowConstants} from "../src/constants/EscrowConstants.sol";
import {EscrowErrors} from "../src/errors/EscrowErrors.sol";
import {ProjectTypes} from "../src/types/ProjectTypes.sol";
import {MilestoneTypes} from "../src/types/MilestoneTypes.sol";

/// @dev Shared setup and helpers. The test contract is the deployer, so it is the owner.
abstract contract BaseTest is Test {
    ChainEscrow internal escrow;

    address internal client;
    address internal freelancer;
    address internal stranger;

    uint256 internal constant BUDGET = 1 ether;
    uint256 internal constant M1 = 0.3 ether;
    uint256 internal constant M2 = 0.7 ether;

    uint256 internal deadline;

    /// @dev Lets the test contract (the owner) receive withdrawn fees
    receive() external payable {}

    function setUp() public virtual {
        escrow = new ChainEscrow();

        client = makeAddr("client");
        freelancer = makeAddr("freelancer");
        stranger = makeAddr("stranger");

        vm.deal(client, 10 ether);
        vm.deal(freelancer, 10 ether);
        vm.deal(stranger, 10 ether);

        deadline = block.timestamp + 30 days;
    }

    // ---------- Builders ----------

    /// @dev Open project with no milestones
    function _createProject() internal returns (uint256 id) {
        vm.prank(client);
        id = escrow.createProject("Build Website", "Create an ecommerce website", BUDGET, deadline);
    }

    /// @dev Open project with milestones 1 (0.3 ETH) and 2 (0.7 ETH) covering the full budget
    function _createReadyProject() internal returns (uint256 id) {
        id = _createProject();
        vm.startPrank(client);
        escrow.createMilestone(id, "UI Design", M1);
        escrow.createMilestone(id, "Backend", M2);
        vm.stopPrank();
    }

    function _createAcceptedProject() internal returns (uint256 id) {
        id = _createReadyProject();
        vm.prank(freelancer);
        escrow.acceptProject(id);
    }

    function _createFundedProject() internal returns (uint256 id) {
        id = _createAcceptedProject();
        vm.prank(client);
        escrow.fundProject{value: BUDGET}(id);
    }

    // ---------- Actions ----------

    function _submit(uint256 id, uint256 milestoneId) internal {
        vm.prank(freelancer);
        escrow.submitMilestone(id, milestoneId);
    }

    function _approve(uint256 id, uint256 milestoneId) internal {
        vm.prank(client);
        escrow.approveMilestone(id, milestoneId);
    }

    function _submitAndApprove(uint256 id, uint256 milestoneId) internal {
        _submit(id, milestoneId);
        _approve(id, milestoneId);
    }

    function _fee(uint256 amount) internal pure returns (uint256) {
        return (amount * EscrowConstants.PLATFORM_FEE_BPS) / EscrowConstants.BPS_DENOMINATOR;
    }
}

contract ProjectTest is BaseTest {
    // ---------- createProject ----------

    function testCreateProject() public {
        uint256 id = _createProject();

        assertEq(id, 1);
        assertEq(escrow.getProjectCount(), 1);

        ProjectTypes.Project memory project = escrow.getProject(id);
        assertEq(project.client, client);
        assertEq(project.freelancer, address(0));
        assertEq(project.budget, BUDGET);
        assertEq(project.deadline, deadline);
        assertEq(uint256(project.status), uint256(ProjectTypes.ProjectStatus.Open));
    }

    function testCreateProjectEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit IChainEscrow.ProjectCreated(1, client, BUDGET);
        _createProject();
    }

    function testCannotCreateProjectWithZeroBudget() public {
        vm.expectRevert(EscrowErrors.InvalidBudget.selector);
        vm.prank(client);
        escrow.createProject("Title", "Desc", 0, deadline);
    }

    function testCannotCreateProjectWithPastDeadline() public {
        vm.expectRevert(EscrowErrors.InvalidDeadline.selector);
        vm.prank(client);
        escrow.createProject("Title", "Desc", BUDGET, block.timestamp);
    }

    // ---------- acceptProject ----------

    function testAcceptProject() public {
        uint256 id = _createReadyProject();

        vm.expectEmit(true, true, false, false);
        emit IChainEscrow.ProjectAccepted(id, freelancer);
        vm.prank(freelancer);
        escrow.acceptProject(id);

        ProjectTypes.Project memory project = escrow.getProject(id);
        assertEq(project.freelancer, freelancer);
        assertEq(uint256(project.status), uint256(ProjectTypes.ProjectStatus.Accepted));
    }

    function testCannotAcceptOwnProject() public {
        uint256 id = _createReadyProject();

        vm.expectRevert(EscrowErrors.ClientCannotAcceptOwnProject.selector);
        vm.prank(client);
        escrow.acceptProject(id);
    }

    function testCannotAcceptProjectTwice() public {
        uint256 id = _createAcceptedProject();

        vm.expectRevert(EscrowErrors.ProjectNotOpen.selector);
        vm.prank(stranger);
        escrow.acceptProject(id);
    }

    function testCannotAcceptNonExistentProject() public {
        vm.expectRevert(EscrowErrors.ProjectDoesNotExist.selector);
        vm.prank(freelancer);
        escrow.acceptProject(999);
    }

    function testCannotAcceptWithoutFullMilestoneAllocation() public {
        uint256 id = _createProject();

        vm.prank(client);
        escrow.createMilestone(id, "UI Design", M1);

        vm.expectRevert(EscrowErrors.MilestonesNotFullyAllocated.selector);
        vm.prank(freelancer);
        escrow.acceptProject(id);
    }

    // ---------- fundProject ----------

    function testFundProject() public {
        uint256 id = _createAcceptedProject();

        vm.expectEmit(true, false, false, true);
        emit IChainEscrow.ProjectFunded(id, BUDGET);
        vm.prank(client);
        escrow.fundProject{value: BUDGET}(id);

        assertEq(escrow.getEscrowBalance(id), BUDGET);
        assertEq(address(escrow).balance, BUDGET);
        assertEq(uint256(escrow.getProject(id).status), uint256(ProjectTypes.ProjectStatus.Funded));
    }

    function testCannotFundWithWrongAmount() public {
        uint256 id = _createAcceptedProject();

        vm.expectRevert(EscrowErrors.IncorrectFundingAmount.selector);
        vm.prank(client);
        escrow.fundProject{value: 0.5 ether}(id);
    }

    function testCannotFundBeforeAcceptance() public {
        uint256 id = _createReadyProject();

        vm.expectRevert(EscrowErrors.ProjectNotAccepted.selector);
        vm.prank(client);
        escrow.fundProject{value: BUDGET}(id);
    }

    function testOnlyClientCanFund() public {
        uint256 id = _createAcceptedProject();

        vm.expectRevert(EscrowErrors.NotProjectClient.selector);
        vm.prank(stranger);
        escrow.fundProject{value: BUDGET}(id);
    }

    function testCannotFundTwice() public {
        uint256 id = _createFundedProject();

        vm.expectRevert(EscrowErrors.ProjectNotAccepted.selector);
        vm.prank(client);
        escrow.fundProject{value: BUDGET}(id);
    }

    

    // ---------- cancelProject ----------

    function testCancelOpenProject() public {
        uint256 id = _createProject();

        vm.prank(client);
        escrow.cancelProject(id);

        assertEq(uint256(escrow.getProject(id).status), uint256(ProjectTypes.ProjectStatus.Cancelled));
    }

    function testCancelAcceptedProject() public {
        uint256 id = _createAcceptedProject();

        vm.prank(client);
        escrow.cancelProject(id);

        assertEq(uint256(escrow.getProject(id).status), uint256(ProjectTypes.ProjectStatus.Cancelled));
    }

    function testCannotCancelFundedProject() public {
        uint256 id = _createFundedProject();

        vm.expectRevert(EscrowErrors.ProjectNotCancellable.selector);
        vm.prank(client);
        escrow.cancelProject(id);
    }

    function testOnlyClientCanCancelProject() public {
        uint256 id = _createProject();

        vm.expectRevert(EscrowErrors.NotProjectClient.selector);
        vm.prank(stranger);
        escrow.cancelProject(id);
    }
}

contract MilestoneTest is BaseTest {
    // ---------- createMilestone ----------

    function testCreateMilestone() public {
        uint256 id = _createProject();

        vm.expectEmit(true, true, false, true);
        emit IChainEscrow.MilestoneCreated(id, 1, M1);
        vm.prank(client);
        uint256 milestoneId = escrow.createMilestone(id, "UI Design", M1);

        assertEq(milestoneId, 1);
        assertEq(escrow.getMilestoneCount(id), 1);

        MilestoneTypes.Milestone memory milestone = escrow.getMilestone(id, 1);
        assertEq(milestone.id, 1);
        assertEq(milestone.title, "UI Design");
        assertEq(milestone.amount, M1);
        assertEq(uint256(milestone.status), uint256(MilestoneTypes.MilestoneStatus.Pending));
    }

    function testOnlyClientCanCreateMilestone() public {
        uint256 id = _createProject();

        vm.expectRevert(EscrowErrors.NotProjectClient.selector);
        vm.prank(freelancer);
        escrow.createMilestone(id, "UI Design", M1);
    }

    function testCannotCreateZeroAmountMilestone() public {
        uint256 id = _createProject();

        vm.expectRevert(EscrowErrors.InvalidMilestoneAmount.selector);
        vm.prank(client);
        escrow.createMilestone(id, "Free", 0);
    }

    function testCannotExceedProjectBudgetWithMilestones() public {
        uint256 id = _createProject();

        vm.startPrank(client);
        escrow.createMilestone(id, "UI Design", 0.6 ether);
        escrow.createMilestone(id, "Frontend", 0.4 ether);

        vm.expectRevert(EscrowErrors.MilestoneBudgetExceeded.selector);
        escrow.createMilestone(id, "Backend", 0.1 ether);
        vm.stopPrank();
    }

    function testCannotCreateTooManyMilestones() public {
        uint256 id = _createProject();

        vm.startPrank(client);
        for (uint256 i = 0; i < EscrowConstants.MAX_MILESTONES; i++) {
            escrow.createMilestone(id, "Step", 1 wei);
        }

        vm.expectRevert(EscrowErrors.TooManyMilestones.selector);
        escrow.createMilestone(id, "One too many", 1 wei);
        vm.stopPrank();
    }

    function testCannotCreateMilestoneAfterAcceptance() public {
        uint256 id = _createAcceptedProject();

        vm.expectRevert(EscrowErrors.ProjectNotOpen.selector);
        vm.prank(client);
        escrow.createMilestone(id, "Sneaky change", 1 wei);
    }

    // ---------- submitMilestone ----------

    function testSubmitMilestone() public {
        uint256 id = _createFundedProject();

        vm.expectEmit(true, true, false, false);
        emit IChainEscrow.MilestoneSubmitted(id, 1);
        _submit(id, 1);

        MilestoneTypes.Milestone memory milestone = escrow.getMilestone(id, 1);
        assertEq(uint256(milestone.status), uint256(MilestoneTypes.MilestoneStatus.Submitted));
        assertEq(milestone.submittedAt, block.timestamp);
    }

    function testOnlyFreelancerCanSubmitMilestone() public {
        uint256 id = _createFundedProject();

        vm.expectRevert(EscrowErrors.NotAssignedFreelancer.selector);
        vm.prank(client);
        escrow.submitMilestone(id, 1);
    }

    function testCannotSubmitBeforeFunding() public {
        uint256 id = _createAcceptedProject();

        vm.expectRevert(EscrowErrors.ProjectNotFunded.selector);
        vm.prank(freelancer);
        escrow.submitMilestone(id, 1);
    }

    function testCannotSubmitNonExistentMilestone() public {
        uint256 id = _createFundedProject();

        vm.expectRevert(EscrowErrors.MilestoneDoesNotExist.selector);
        vm.prank(freelancer);
        escrow.submitMilestone(id, 99);
    }

    function testCannotSubmitMilestoneTwice() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.expectRevert(EscrowErrors.MilestoneNotPending.selector);
        vm.prank(freelancer);
        escrow.submitMilestone(id, 1);
    }

    // ---------- approveMilestone ----------

    function testApproveMilestone() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.expectEmit(true, true, false, false);
        emit IChainEscrow.MilestoneApproved(id, 1);
        _approve(id, 1);

        assertEq(
            uint256(escrow.getMilestone(id, 1).status),
            uint256(MilestoneTypes.MilestoneStatus.Approved)
        );
    }

    function testOnlyClientCanApproveMilestone() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.expectRevert(EscrowErrors.NotProjectClient.selector);
        vm.prank(freelancer);
        escrow.approveMilestone(id, 1);
    }

    function testCannotApproveBeforeSubmission() public {
        uint256 id = _createFundedProject();

        vm.expectRevert(EscrowErrors.MilestoneNotSubmitted.selector);
        vm.prank(client);
        escrow.approveMilestone(id, 1);
    }

    // ---------- payMilestone ----------

    function testPayMilestoneByClient() public {
        uint256 id = _createFundedProject();
        _submitAndApprove(id, 1);

        uint256 balanceBefore = freelancer.balance;

        vm.expectEmit(true, true, false, true);
        emit IChainEscrow.MilestonePaid(id, 1, M1 - _fee(M1), _fee(M1));
        vm.prank(client);
        escrow.payMilestone(id, 1);

        assertEq(freelancer.balance, balanceBefore + 0.285 ether);
        assertEq(escrow.getEscrowBalance(id), BUDGET - M1);
        assertEq(uint256(escrow.getMilestone(id, 1).status), uint256(MilestoneTypes.MilestoneStatus.Paid));
    }

    function testFreelancerCanPayApprovedMilestone() public {
        uint256 id = _createFundedProject();
        _submitAndApprove(id, 1);

        uint256 balanceBefore = freelancer.balance;

        vm.prank(freelancer);
        escrow.payMilestone(id, 1);

        assertEq(freelancer.balance, balanceBefore + 0.285 ether);
    }

    function testStrangerCannotPayMilestone() public {
        uint256 id = _createFundedProject();
        _submitAndApprove(id, 1);

        vm.expectRevert(EscrowErrors.NotProjectParticipant.selector);
        vm.prank(stranger);
        escrow.payMilestone(id, 1);
    }

    function testCannotPayUnapprovedMilestone() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.expectRevert(EscrowErrors.MilestoneNotApproved.selector);
        vm.prank(client);
        escrow.payMilestone(id, 1);
    }

    function testCannotPayMilestoneTwice() public {
        uint256 id = _createFundedProject();
        _submitAndApprove(id, 1);

        vm.prank(client);
        escrow.payMilestone(id, 1);

        vm.expectRevert(EscrowErrors.MilestoneNotApproved.selector);
        vm.prank(client);
        escrow.payMilestone(id, 1);
    }

    function testProjectCompletesWhenAllMilestonesPaid() public {
        uint256 id = _createFundedProject();

        _submitAndApprove(id, 1);
        _submitAndApprove(id, 2);

        vm.prank(client);
        escrow.payMilestone(id, 1);

        vm.expectEmit(true, false, false, false);
        emit IChainEscrow.ProjectCompleted(id);
        vm.prank(client);
        escrow.payMilestone(id, 2);

        assertEq(uint256(escrow.getProject(id).status), uint256(ProjectTypes.ProjectStatus.Completed));
        assertEq(escrow.getEscrowBalance(id), 0);
    }

    // ---------- claimMilestoneAfterReview ----------

    function testFreelancerCanClaimAfterReviewPeriod() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.warp(block.timestamp + EscrowConstants.REVIEW_PERIOD);

        uint256 balanceBefore = freelancer.balance;
        vm.prank(freelancer);
        escrow.claimMilestoneAfterReview(id, 1);

        assertEq(freelancer.balance, balanceBefore + M1 - _fee(M1));
        assertEq(uint256(escrow.getMilestone(id, 1).status), uint256(MilestoneTypes.MilestoneStatus.Paid));
    }

    function testCannotClaimBeforeReviewPeriodEnds() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.warp(block.timestamp + EscrowConstants.REVIEW_PERIOD - 1);

        vm.expectRevert(EscrowErrors.ReviewPeriodNotElapsed.selector);
        vm.prank(freelancer);
        escrow.claimMilestoneAfterReview(id, 1);
    }

    function testOnlyFreelancerCanClaimAfterReview() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.warp(block.timestamp + EscrowConstants.REVIEW_PERIOD);

        vm.expectRevert(EscrowErrors.NotAssignedFreelancer.selector);
        vm.prank(client);
        escrow.claimMilestoneAfterReview(id, 1);
    }
}

contract RefundTest is BaseTest {
    function testRefundClientBeforeAnySubmission() public {
        uint256 id = _createFundedProject();
        uint256 balanceBefore = client.balance;

        vm.expectEmit(true, true, false, true);
        emit IChainEscrow.RefundIssued(id, client, BUDGET);
        vm.prank(client);
        escrow.refundClient(id);

        assertEq(client.balance, balanceBefore + BUDGET);
        assertEq(escrow.getEscrowBalance(id), 0);
        assertEq(address(escrow).balance, 0);
        assertEq(uint256(escrow.getProject(id).status), uint256(ProjectTypes.ProjectStatus.Cancelled));
    }

    function testCannotRefundAfterSubmissionBeforeDeadline() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.expectRevert(EscrowErrors.RefundNotAvailable.selector);
        vm.prank(client);
        escrow.refundClient(id);
    }

    /// @dev Regression test: a client must not be able to approve work and then take the money back
    function testClientCannotStealApprovedWork() public {
        uint256 id = _createFundedProject();
        _submitAndApprove(id, 1);

        vm.expectRevert(EscrowErrors.RefundNotAvailable.selector);
        vm.prank(client);
        escrow.refundClient(id);

        // The freelancer can still get paid
        uint256 balanceBefore = freelancer.balance;
        vm.prank(freelancer);
        escrow.payMilestone(id, 1);
        assertEq(freelancer.balance, balanceBefore + M1 - _fee(M1));
    }

    function testOnlyClientCanRefund() public {
        uint256 id = _createFundedProject();

        vm.expectRevert(EscrowErrors.NotProjectClient.selector);
        vm.prank(stranger);
        escrow.refundClient(id);
    }

    function testCannotRefundTwice() public {
        uint256 id = _createFundedProject();

        vm.prank(client);
        escrow.refundClient(id);

        vm.expectRevert(EscrowErrors.ProjectNotFunded.selector);
        vm.prank(client);
        escrow.refundClient(id);
    }

    function testCannotRefundUnfundedProject() public {
        uint256 id = _createAcceptedProject();

        vm.expectRevert(EscrowErrors.ProjectNotFunded.selector);
        vm.prank(client);
        escrow.refundClient(id);
    }

    function testRefundPendingMilestonesAfterDeadline() public {
        uint256 id = _createFundedProject();
        _submit(id, 1); // milestone 1 submitted, milestone 2 never started

        vm.warp(deadline + 1);

        uint256 balanceBefore = client.balance;
        vm.prank(client);
        escrow.refundClient(id);

        // Only the untouched milestone (M2) is refunded
        assertEq(client.balance, balanceBefore + M2);
        assertEq(escrow.getEscrowBalance(id), M1);
        assertEq(uint256(escrow.getMilestone(id, 1).status), uint256(MilestoneTypes.MilestoneStatus.Submitted));
        assertEq(uint256(escrow.getMilestone(id, 2).status), uint256(MilestoneTypes.MilestoneStatus.Cancelled));
        assertEq(uint256(escrow.getProject(id).status), uint256(ProjectTypes.ProjectStatus.Funded));

        // The freelancer can still collect the submitted milestone, which completes the project
        vm.prank(freelancer);
        escrow.claimMilestoneAfterReview(id, 1);

        assertEq(escrow.getEscrowBalance(id), 0);
        assertEq(uint256(escrow.getProject(id).status), uint256(ProjectTypes.ProjectStatus.Completed));
    }

    function testCannotRefundAfterDeadlineWhenNothingIsPending() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);
        _submit(id, 2);

        vm.warp(deadline + 1);

        vm.expectRevert(EscrowErrors.NoFundsAvailable.selector);
        vm.prank(client);
        escrow.refundClient(id);
    }
}

contract DisputeTest is BaseTest {
    function testClientCanOpenDispute() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.expectEmit(true, true, true, false);
        emit IChainEscrow.DisputeOpened(id, 1, client);
        vm.prank(client);
        escrow.openDispute(id, 1);

        assertEq(uint256(escrow.getMilestone(id, 1).status), uint256(MilestoneTypes.MilestoneStatus.Disputed));
    }

    function testOnlyClientCanOpenDispute() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.expectRevert(EscrowErrors.NotProjectClient.selector);
        vm.prank(freelancer);
        escrow.openDispute(id, 1);
    }

    function testCannotDisputePendingMilestone() public {
        uint256 id = _createFundedProject();

        vm.expectRevert(EscrowErrors.MilestoneNotSubmitted.selector);
        vm.prank(client);
        escrow.openDispute(id, 1);
    }

    function testFreelancerCannotClaimDisputedMilestone() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.prank(client);
        escrow.openDispute(id, 1);

        vm.warp(block.timestamp + 30 days);

        vm.expectRevert(EscrowErrors.MilestoneNotSubmitted.selector);
        vm.prank(freelancer);
        escrow.claimMilestoneAfterReview(id, 1);
    }

    function testOwnerResolvesDisputeInFavourOfFreelancer() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.prank(client);
        escrow.openDispute(id, 1);

        uint256 balanceBefore = freelancer.balance;

        vm.expectEmit(true, true, false, true);
        emit IChainEscrow.DisputeResolved(id, 1, true);
        escrow.resolveDispute(id, 1, true); // test contract is the owner

        assertEq(freelancer.balance, balanceBefore + M1 - _fee(M1));
        assertEq(escrow.getPlatformBalance(), _fee(M1));
        assertEq(uint256(escrow.getMilestone(id, 1).status), uint256(MilestoneTypes.MilestoneStatus.Paid));
    }

    function testOwnerResolvesDisputeInFavourOfClient() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.prank(client);
        escrow.openDispute(id, 1);

        uint256 balanceBefore = client.balance;

        vm.expectEmit(true, true, false, true);
        emit IChainEscrow.DisputeResolved(id, 1, false);
        escrow.resolveDispute(id, 1, false);

        assertEq(client.balance, balanceBefore + M1);
        assertEq(escrow.getPlatformBalance(), 0);
        assertEq(escrow.getEscrowBalance(id), BUDGET - M1);
        assertEq(uint256(escrow.getMilestone(id, 1).status), uint256(MilestoneTypes.MilestoneStatus.Cancelled));
    }

    function testOnlyOwnerCanResolveDispute() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.prank(client);
        escrow.openDispute(id, 1);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, client));
        vm.prank(client);
        escrow.resolveDispute(id, 1, false);
    }

    function testCannotResolveUndisputedMilestone() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.expectRevert(EscrowErrors.MilestoneNotDisputed.selector);
        escrow.resolveDispute(id, 1, true);
    }
}

contract FeesTest is BaseTest {
    function testOwnerIsDeployer() public view {
        assertEq(escrow.owner(), address(this));
    }

    function testPlatformFeeCollected() public {
        uint256 id = _createFundedProject();
        _submitAndApprove(id, 1);

        vm.prank(client);
        escrow.payMilestone(id, 1);

        assertEq(escrow.getPlatformBalance(), 0.015 ether);
    }

    function testWithdrawPlatformFees() public {
        uint256 id = _createFundedProject();
        _submitAndApprove(id, 1);

        vm.prank(client);
        escrow.payMilestone(id, 1);

        uint256 ownerBalanceBefore = address(this).balance;

        vm.expectEmit(true, false, false, true);
        emit IChainEscrow.PlatformFeesWithdrawn(address(this), 0.015 ether);
        escrow.withdrawPlatformFees();

        assertEq(escrow.getPlatformBalance(), 0);
        assertEq(address(this).balance, ownerBalanceBefore + 0.015 ether);
    }

    function testOnlyOwnerCanWithdrawPlatformFees() public {
        uint256 id = _createFundedProject();
        _submitAndApprove(id, 1);

        vm.prank(client);
        escrow.payMilestone(id, 1);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, client));
        vm.prank(client);
        escrow.withdrawPlatformFees();
    }

    function testCannotWithdrawWhenNoFees() public {
        vm.expectRevert(EscrowErrors.NoFeesAvailable.selector);
        escrow.withdrawPlatformFees();
    }

    /// @dev Escrow's ETH balance must always equal locked project funds plus unwithdrawn fees
    function testContractBalanceMatchesAccounting() public {
        uint256 id = _createFundedProject();
        _submitAndApprove(id, 1);

        vm.prank(client);
        escrow.payMilestone(id, 1);

        assertEq(
            address(escrow).balance,
            escrow.getEscrowBalance(id) + escrow.getPlatformBalance()
        );
    }

    /// @dev For any amount, payout + fee must equal the milestone amount (no wei lost)
    function testFuzz_FeeAndPayoutSumToAmount(uint256 amount) public {
        amount = bound(amount, 1, 100 ether);
        vm.deal(client, amount);

        vm.startPrank(client);
        uint256 id = escrow.createProject("Title", "Desc", amount, block.timestamp + 1 days);
        escrow.createMilestone(id, "Only milestone", amount);
        vm.stopPrank();

        vm.prank(freelancer);
        escrow.acceptProject(id);

        vm.prank(client);
        escrow.fundProject{value: amount}(id);

        _submitAndApprove(id, 1);

        uint256 freelancerBefore = freelancer.balance;

        vm.prank(client);
        escrow.payMilestone(id, 1);

        uint256 payout = freelancer.balance - freelancerBefore;

        assertEq(payout + escrow.getPlatformBalance(), amount);
        assertEq(address(escrow).balance, escrow.getPlatformBalance());
    }
}

contract DeadlineTest is BaseTest {
    uint256 internal newDeadline;

    function setUp() public override {
        super.setUp();
        newDeadline = deadline + 7 days;
    }

    // ---------- propose ----------

    function testClientCanProposeExtension() public {
        uint256 id = _createFundedProject();

        vm.expectEmit(true, true, false, true);
        emit IChainEscrow.DeadlineExtensionProposed(id, client, newDeadline);
        vm.prank(client);
        escrow.proposeDeadlineExtension(id, newDeadline);

        (address proposer, uint256 proposed) = escrow.getDeadlineProposal(id);
        assertEq(proposer, client);
        assertEq(proposed, newDeadline);
        // Nothing changes until the other side accepts
        assertEq(escrow.getProject(id).deadline, deadline);
    }

    function testCanProposeWhileAccepted() public {
        uint256 id = _createAcceptedProject();

        vm.prank(freelancer);
        escrow.proposeDeadlineExtension(id, newDeadline);

        (address proposer,) = escrow.getDeadlineProposal(id);
        assertEq(proposer, freelancer);
    }

    function testStrangerCannotPropose() public {
        uint256 id = _createFundedProject();

        vm.expectRevert(EscrowErrors.NotProjectParticipant.selector);
        vm.prank(stranger);
        escrow.proposeDeadlineExtension(id, newDeadline);
    }

    function testCannotProposeOnOpenProject() public {
        uint256 id = _createReadyProject();

        vm.expectRevert(EscrowErrors.ProjectNotActive.selector);
        vm.prank(client);
        escrow.proposeDeadlineExtension(id, newDeadline);
    }

    function testCannotProposeOnCancelledProject() public {
        uint256 id = _createAcceptedProject();

        vm.prank(client);
        escrow.cancelProject(id);

        vm.expectRevert(EscrowErrors.ProjectNotActive.selector);
        vm.prank(client);
        escrow.proposeDeadlineExtension(id, newDeadline);
    }

    function testCannotProposeNonExistentProject() public {
        vm.expectRevert(EscrowErrors.ProjectDoesNotExist.selector);
        vm.prank(client);
        escrow.proposeDeadlineExtension(999, newDeadline);
    }

    function testCannotProposeEarlierDeadline() public {
        uint256 id = _createFundedProject();

        vm.expectRevert(EscrowErrors.DeadlineNotExtended.selector);
        vm.prank(client);
        escrow.proposeDeadlineExtension(id, deadline - 1 days);
    }

    function testCannotProposeSameDeadline() public {
        uint256 id = _createFundedProject();

        vm.expectRevert(EscrowErrors.DeadlineNotExtended.selector);
        vm.prank(client);
        escrow.proposeDeadlineExtension(id, deadline);
    }

    function testCannotProposeDeadlineInThePast() public {
        uint256 id = _createFundedProject();

        vm.warp(deadline + 10 days);

        vm.expectRevert(EscrowErrors.InvalidDeadline.selector);
        vm.prank(client);
        escrow.proposeDeadlineExtension(id, deadline + 1 days);
    }

    function testNewProposalOverwritesOldOne() public {
        uint256 id = _createFundedProject();

        vm.prank(client);
        escrow.proposeDeadlineExtension(id, newDeadline);

        vm.prank(freelancer);
        escrow.proposeDeadlineExtension(id, newDeadline + 3 days);

        (address proposer, uint256 proposed) = escrow.getDeadlineProposal(id);
        assertEq(proposer, freelancer);
        assertEq(proposed, newDeadline + 3 days);
    }

    // ---------- accept ----------

    function testFreelancerAcceptsClientProposal() public {
        uint256 id = _createFundedProject();

        vm.prank(client);
        escrow.proposeDeadlineExtension(id, newDeadline);

        vm.expectEmit(true, false, false, true);
        emit IChainEscrow.DeadlineExtended(id, deadline, newDeadline);
        vm.prank(freelancer);
        escrow.acceptDeadlineExtension(id);

        assertEq(escrow.getProject(id).deadline, newDeadline);

        // Proposal is cleared after acceptance
        (address proposer, uint256 proposed) = escrow.getDeadlineProposal(id);
        assertEq(proposer, address(0));
        assertEq(proposed, 0);
    }

    function testClientAcceptsFreelancerProposal() public {
        uint256 id = _createFundedProject();

        vm.prank(freelancer);
        escrow.proposeDeadlineExtension(id, newDeadline);

        vm.prank(client);
        escrow.acceptDeadlineExtension(id);

        assertEq(escrow.getProject(id).deadline, newDeadline);
    }

    function testProposerCannotAcceptOwnProposal() public {
        uint256 id = _createFundedProject();

        vm.prank(client);
        escrow.proposeDeadlineExtension(id, newDeadline);

        vm.expectRevert(EscrowErrors.CannotAcceptOwnProposal.selector);
        vm.prank(client);
        escrow.acceptDeadlineExtension(id);
    }

    function testStrangerCannotAcceptExtension() public {
        uint256 id = _createFundedProject();

        vm.prank(client);
        escrow.proposeDeadlineExtension(id, newDeadline);

        vm.expectRevert(EscrowErrors.NotProjectParticipant.selector);
        vm.prank(stranger);
        escrow.acceptDeadlineExtension(id);
    }

    function testCannotAcceptWithoutProposal() public {
        uint256 id = _createFundedProject();

        vm.expectRevert(EscrowErrors.NoPendingExtension.selector);
        vm.prank(freelancer);
        escrow.acceptDeadlineExtension(id);
    }

    function testCannotAcceptTwice() public {
        uint256 id = _createFundedProject();

        vm.prank(client);
        escrow.proposeDeadlineExtension(id, newDeadline);

        vm.prank(freelancer);
        escrow.acceptDeadlineExtension(id);

        vm.expectRevert(EscrowErrors.NoPendingExtension.selector);
        vm.prank(freelancer);
        escrow.acceptDeadlineExtension(id);
    }

    function testCannotAcceptStaleProposal() public {
        uint256 id = _createFundedProject();

        vm.prank(client);
        escrow.proposeDeadlineExtension(id, deadline + 1 days);

        vm.warp(deadline + 2 days);

        vm.expectRevert(EscrowErrors.InvalidDeadline.selector);
        vm.prank(freelancer);
        escrow.acceptDeadlineExtension(id);
    }

    // ---------- isOverdue ----------

    function testIsOverdue() public {
        uint256 id = _createFundedProject();

        assertFalse(escrow.isOverdue(id));

        vm.warp(deadline);
        assertFalse(escrow.isOverdue(id)); // exactly at the deadline is not overdue yet

        vm.warp(deadline + 1);
        assertTrue(escrow.isOverdue(id));
    }

    function testExtensionClearsOverdue() public {
        uint256 id = _createFundedProject();

        vm.warp(deadline + 1);
        assertTrue(escrow.isOverdue(id));

        uint256 extended = block.timestamp + 5 days;

        vm.prank(client);
        escrow.proposeDeadlineExtension(id, extended);

        vm.prank(freelancer);
        escrow.acceptDeadlineExtension(id);

        assertFalse(escrow.isOverdue(id));
    }

    function testIsNotOverdueForNonActiveProjects() public {
        uint256 openId = _createProject();
        vm.warp(deadline + 1);

        assertFalse(escrow.isOverdue(openId));
        assertFalse(escrow.isOverdue(999));
    }

    // ---------- integration with refunds ----------

    function testExtensionDelaysDeadlineRefund() public {
        uint256 id = _createFundedProject();
        _submit(id, 1);

        vm.prank(client);
        escrow.proposeDeadlineExtension(id, deadline + 14 days);

        vm.prank(freelancer);
        escrow.acceptDeadlineExtension(id);

        // Past the ORIGINAL deadline, but inside the extended one
        vm.warp(deadline + 1);

        vm.expectRevert(EscrowErrors.RefundNotAvailable.selector);
        vm.prank(client);
        escrow.refundClient(id);

        // Past the extended deadline the refund works again
        vm.warp(deadline + 14 days + 1);

        uint256 balanceBefore = client.balance;
        vm.prank(client);
        escrow.refundClient(id);

        assertEq(client.balance, balanceBefore + M2);
    }
}

/// @dev Test helper: a contract that can act as client or freelancer. When it receives ETH it can
///      try to re-enter the escrow with a stored payload, or reject the payment outright.
contract MaliciousParty {
    address public immutable target;

    bytes public payload;
    bool public rejectEth;

    bool public attacked;
    bool public reentrySucceeded;
    bytes public reentryRevertData;

    constructor(address _target) {
        target = _target;
    }

    function setPayload(bytes calldata data) external {
        payload = data;
    }

    function setRejectEth(bool value) external {
        rejectEth = value;
    }

    /// @dev Forwards a call to the escrow with this contract as msg.sender, bubbling up reverts
    function exec(bytes calldata data) external payable returns (bytes memory ret) {
        bool ok;
        (ok, ret) = target.call{value: msg.value}(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    receive() external payable {
        if (rejectEth) revert("ETH rejected");
        if (attacked || payload.length == 0) return;

        attacked = true;
        (bool ok, bytes memory ret) = target.call(payload);
        reentrySucceeded = ok;
        if (!ok) reentryRevertData = ret;
    }
}

contract MaliciousPartyTest is BaseTest {
    // ---------- helpers ----------

    /// @dev Funded project where the attacker contract is the freelancer. Milestone 1 is approved.
    function _approvedProjectWithAttackerFreelancer(MaliciousParty attacker) internal returns (uint256 id) {
        id = _createReadyProject();

        attacker.exec(abi.encodeCall(escrow.acceptProject, (id)));

        vm.prank(client);
        escrow.fundProject{value: BUDGET}(id);

        attacker.exec(abi.encodeCall(escrow.submitMilestone, (id, 1)));
        _approve(id, 1);
    }

    /// @dev Funded project where the attacker contract is the client
    function _fundedProjectWithAttackerClient(MaliciousParty attacker) internal returns (uint256 id) {
        id = abi.decode(
            attacker.exec(abi.encodeWithSelector(escrow.createProject.selector, "Title", "Desc", BUDGET, deadline)),
            (uint256)
        );
        attacker.exec(abi.encodeWithSelector(escrow.createMilestone.selector, id, "Only milestone", BUDGET));

        vm.prank(freelancer);
        escrow.acceptProject(id);

        vm.prank(client);
        attacker.exec{value: BUDGET}(abi.encodeCall(escrow.fundProject, (id)));
    }

    // ---------- reentrancy ----------

    function testFreelancerReentrancyOnPayMilestoneIsBlocked() public {
        MaliciousParty attacker = new MaliciousParty(address(escrow));
        uint256 id = _approvedProjectWithAttackerFreelancer(attacker);

        // When the payout arrives, the attacker tries to call payMilestone again
        attacker.setPayload(abi.encodeCall(escrow.payMilestone, (id, 1)));

        vm.prank(client);
        escrow.payMilestone(id, 1);

        assertTrue(attacker.attacked());
        assertFalse(attacker.reentrySucceeded());
        assertEq(bytes4(attacker.reentryRevertData()), ReentrancyGuard.ReentrancyGuardReentrantCall.selector);

        // Paid exactly once
        assertEq(address(attacker).balance, M1 - _fee(M1));
        assertEq(escrow.getEscrowBalance(id), BUDGET - M1);
        assertEq(escrow.getPlatformBalance(), _fee(M1));
        assertEq(address(escrow).balance, BUDGET - M1 + _fee(M1));
    }

    function testClientReentrancyOnRefundIsBlocked() public {
        MaliciousParty attacker = new MaliciousParty(address(escrow));
        uint256 id = _fundedProjectWithAttackerClient(attacker);

        // When the refund arrives, the attacker tries to refund again
        attacker.setPayload(abi.encodeCall(escrow.refundClient, (id)));

        attacker.exec(abi.encodeCall(escrow.refundClient, (id)));

        assertTrue(attacker.attacked());
        assertFalse(attacker.reentrySucceeded());
        assertEq(bytes4(attacker.reentryRevertData()), ReentrancyGuard.ReentrancyGuardReentrantCall.selector);

        // Refunded exactly once
        assertEq(address(attacker).balance, BUDGET);
        assertEq(address(escrow).balance, 0);
        assertEq(escrow.getEscrowBalance(id), 0);
    }

    // ---------- recipients that reject ETH ----------

    function testRejectingFreelancerRevertsAndLosesNothing() public {
        MaliciousParty rejecter = new MaliciousParty(address(escrow));
        rejecter.setRejectEth(true);
        uint256 id = _approvedProjectWithAttackerFreelancer(rejecter);

        vm.expectRevert(EscrowErrors.TransferFailed.selector);
        vm.prank(client);
        escrow.payMilestone(id, 1);

        // Everything was rolled back
        assertEq(uint256(escrow.getMilestone(id, 1).status), uint256(MilestoneTypes.MilestoneStatus.Approved));
        assertEq(escrow.getEscrowBalance(id), BUDGET);
        assertEq(escrow.getPlatformBalance(), 0);
        assertEq(address(escrow).balance, BUDGET);

        // Once the recipient can receive ETH again, the payment goes through
        rejecter.setRejectEth(false);

        vm.prank(client);
        escrow.payMilestone(id, 1);

        assertEq(address(rejecter).balance, M1 - _fee(M1));
    }

    function testRejectingClientRefundRevertsAndLosesNothing() public {
        MaliciousParty rejecter = new MaliciousParty(address(escrow));
        rejecter.setRejectEth(true);
        uint256 id = _fundedProjectWithAttackerClient(rejecter);

        vm.expectRevert(EscrowErrors.TransferFailed.selector);
        rejecter.exec(abi.encodeCall(escrow.refundClient, (id)));

        assertEq(uint256(escrow.getProject(id).status), uint256(ProjectTypes.ProjectStatus.Funded));
        assertEq(escrow.getEscrowBalance(id), BUDGET);
        assertEq(address(escrow).balance, BUDGET);
    }
}

contract OwnershipTest is BaseTest {
    function testRenounceOwnershipIsDisabled() public {
        vm.expectRevert(EscrowErrors.RenounceOwnershipDisabled.selector);
        escrow.renounceOwnership();

        assertEq(escrow.owner(), address(this));
    }

    function testRenounceOwnershipIsDisabledForEveryone() public {
        vm.expectRevert(EscrowErrors.RenounceOwnershipDisabled.selector);
        vm.prank(stranger);
        escrow.renounceOwnership();
    }

    function testOwnershipTransferIsTwoStep() public {
        address newOwner = makeAddr("newOwner");

        escrow.transferOwnership(newOwner);

        // Nothing changes until the new owner accepts
        assertEq(escrow.owner(), address(this));
        assertEq(escrow.pendingOwner(), newOwner);

        vm.prank(newOwner);
        escrow.acceptOwnership();

        assertEq(escrow.owner(), newOwner);
        assertEq(escrow.pendingOwner(), address(0));
    }

    function testOnlyPendingOwnerCanAcceptOwnership() public {
        escrow.transferOwnership(makeAddr("newOwner"));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        vm.prank(stranger);
        escrow.acceptOwnership();
    }
}
