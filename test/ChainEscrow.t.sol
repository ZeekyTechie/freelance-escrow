// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/ChainEscrow.sol";
import "../src/types/MilestoneTypes.sol";

contract ChainEscrowTest is Test {

    receive() external payable {}
    
    ChainEscrow escrow;

    
    address client = address(1);
    address freelancer = address(2);

    function setUp() public {
        escrow = new ChainEscrow();

        vm.deal(client, 10 ether);
        vm.deal(freelancer, 10 ether);
    }

    function testCreateProject() public {

        vm.prank(client);

        escrow.createProject(
            "Build Website",
            "Create an ecommerce website",
            1 ether,
            block.timestamp + 30 days
        );

        assertEq(
            escrow.getProjectCount(),
            1
        );
    }

    function testAcceptProject() public {

    vm.prank(client);

    escrow.createProject(
        "Build Website",
        "Create an ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(freelancer);

    escrow.acceptProject(1);

    ProjectTypes.Project memory project =
        escrow.getProject(1);

    assertEq(
        project.freelancer,
        freelancer
    );
}

function testFundProject() public {

    vm.prank(client);

    escrow.createProject(
        "Build Website",
        "Create an ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(freelancer);

    escrow.acceptProject(1);

    vm.prank(client);

    escrow.fundProject{value: 1 ether}(1);

    assertEq(
        escrow.getEscrowBalance(1),
        1 ether
    );
}

function testSubmitWork() public {

    vm.prank(client);

    escrow.createProject(
        "Build Website",
        "Create an ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(client);
    escrow.fundProject{value: 1 ether}(1);

    vm.prank(freelancer);
    escrow.submitWork(1);

    ProjectTypes.Project memory project =
        escrow.getProject(1);

    assertEq(
        uint256(project.status),
        uint256(ProjectTypes.ProjectStatus.Submitted)
    );
}

function testApproveWork() public {

    vm.prank(client);
    escrow.createProject(
        "Build Website",
        "Create an ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(client);
    escrow.fundProject{value: 1 ether}(1);

    vm.prank(freelancer);
    escrow.submitWork(1);

    vm.prank(client);
    escrow.approveWork(1);

    ProjectTypes.Project memory project =
        escrow.getProject(1);

    assertEq(
        uint256(project.status),
        uint256(ProjectTypes.ProjectStatus.Completed)
    );
}

function testReleasePayment() public {

    vm.prank(client);
    escrow.createProject(
        "Build Website",
        "Create an ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(client);
    escrow.fundProject{value: 1 ether}(1);

    vm.prank(freelancer);
    escrow.submitWork(1);

    vm.prank(client);
    escrow.approveWork(1);

    uint256 balanceBefore =
        freelancer.balance;

    vm.prank(client);
    escrow.releasePayment(1);

    uint256 balanceAfter =
        freelancer.balance;

    assertEq(
        balanceAfter,
        balanceBefore + 1 ether
    );
}

function testRefundClient() public {

    vm.prank(client);
    escrow.createProject(
        "Build Website",
        "Create an ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(client);
    escrow.fundProject{value: 1 ether}(1);

    uint256 balanceBefore =
        client.balance;

    vm.prank(client);
    escrow.refundClient(1);

    uint256 balanceAfter =
        client.balance;

    assertEq(
        balanceAfter,
        balanceBefore + 1 ether
    );
}

function testOnlyFreelancerCanSubmitWork() public {

    vm.prank(client);
    escrow.createProject(
        "Build Website",
        "Create an ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(client);
    escrow.fundProject{value: 1 ether}(1);

    vm.expectRevert();

    vm.prank(client);
    escrow.submitWork(1);
}

function testCannotFundWithWrongAmount() public {

    vm.prank(client);
    escrow.createProject(
        "Build Website",
        "Create an ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.expectRevert();

    vm.prank(client);
    escrow.fundProject{value: 0.5 ether}(1);
}

function testOnlyClientCanApproveWork() public {

    vm.prank(client);
    escrow.createProject(
        "Build Website",
        "Create an ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(client);
    escrow.fundProject{value: 1 ether}(1);

    vm.prank(freelancer);
    escrow.submitWork(1);

    vm.expectRevert();

    vm.prank(freelancer);
    escrow.approveWork(1);
}

function testCannotApproveBeforeSubmission() public {

    vm.prank(client);
    escrow.createProject(
        "Build Website",
        "Create an ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(client);
    escrow.fundProject{value: 1 ether}(1);

    vm.expectRevert();

    vm.prank(client);
    escrow.approveWork(1);
}

function testCannotReleasePaymentTwice() public {

    vm.prank(client);
    escrow.createProject(
        "Build Website",
        "Create an ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(client);
    escrow.fundProject{value: 1 ether}(1);

    vm.prank(freelancer);
    escrow.submitWork(1);

    vm.prank(client);
    escrow.approveWork(1);

    vm.prank(client);
    escrow.releasePayment(1);

    vm.expectRevert();

    vm.prank(client);
    escrow.releasePayment(1);
}

function testCannotRefundAfterSubmission() public {

    vm.prank(client);
    escrow.createProject(
        "Build Website",
        "Create an ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(client);
    escrow.fundProject{value: 1 ether}(1);

    vm.prank(freelancer);
    escrow.submitWork(1);

    vm.expectRevert();

    vm.prank(client);
    escrow.refundClient(1);
}

function testCannotAcceptProjectTwice() public {

    vm.prank(client);
    escrow.createProject(
        "Build Website",
        "Create an ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.expectRevert();

    vm.prank(address(3));
    escrow.acceptProject(1);
}

function testCannotFundBeforeAcceptance() public {

    vm.prank(client);

    escrow.createProject(
        "Build Website",
        "Create an ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.expectRevert();

    vm.prank(client);
    escrow.fundProject{value: 1 ether}(1);
}

function testCannotAcceptNonExistentProject() public {

    vm.expectRevert();

    vm.prank(freelancer);
    escrow.acceptProject(999);
}

function testCreateMilestone() public {

    vm.prank(client);

    escrow.createProject(
        "Build Website",
        "Create ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(client);

    escrow.createMilestone(
        1,
        "UI Design",
        0.3 ether
    );

    MilestoneTypes.Milestone memory milestone =
        escrow.getMilestone(1, 1);

    assertEq(
        milestone.amount,
        0.3 ether
    );
}

function testOnlyClientCanCreateMilestone() public {

    vm.prank(client);

    escrow.createProject(
        "Build Website",
        "Create ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.expectRevert();

    vm.prank(freelancer);

    escrow.createMilestone(
        1,
        "UI Design",
        0.3 ether
    );
}

function testGetMilestone() public {

    vm.prank(client);

    escrow.createProject(
        "Build Website",
        "Create ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(client);

    escrow.createMilestone(
        1,
        "Frontend Development",
        0.4 ether
    );

    MilestoneTypes.Milestone memory milestone =
        escrow.getMilestone(1, 1);

    assertEq(
        milestone.id,
        1
    );

    assertEq(
        milestone.title,
        "Frontend Development"
    );
}

function testSubmitMilestone() public {

    vm.prank(client);

    escrow.createProject(
        "Build Website",
        "Create ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(client);

    escrow.createMilestone(
        1,
        "UI Design",
        0.3 ether
    );

    vm.prank(freelancer);

    escrow.acceptProject(1);

    vm.prank(freelancer);

    escrow.submitMilestone(
        1,
        1
    );

    MilestoneTypes.Milestone memory milestone =
        escrow.getMilestone(1, 1);

    assertEq(
        uint256(milestone.status),
        uint256(
            MilestoneTypes.MilestoneStatus.Submitted
        )
    );
}

function testOnlyFreelancerCanSubmitMilestone()
    public
{
    vm.prank(client);

    escrow.createProject(
        "Build Website",
        "Create ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(client);

    escrow.createMilestone(
        1,
        "UI Design",
        0.3 ether
    );

    vm.prank(freelancer);

    escrow.acceptProject(1);

    vm.expectRevert();

    vm.prank(client);

    escrow.submitMilestone(
        1,
        1
    );
}

function testApproveMilestone() public {

    vm.prank(client);
    escrow.createProject(
        "Build Website",
        "Create ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(client);
    escrow.createMilestone(
        1,
        "UI Design",
        0.3 ether
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(freelancer);
    escrow.submitMilestone(1, 1);

    vm.prank(client);
    escrow.approveMilestone(1, 1);

    MilestoneTypes.Milestone memory milestone =
        escrow.getMilestone(1, 1);

    assertEq(
        uint256(milestone.status),
        uint256(
            MilestoneTypes.MilestoneStatus.Approved
        )
    );
}

function testOnlyClientCanApproveMilestone()
    public
{
    vm.prank(client);
    escrow.createProject(
        "Build Website",
        "Create ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(client);
    escrow.createMilestone(
        1,
        "UI Design",
        0.3 ether
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(freelancer);
    escrow.submitMilestone(1, 1);

    vm.expectRevert();

    vm.prank(freelancer);
    escrow.approveMilestone(1, 1);
}

function testPayMilestone() public {

    vm.prank(client);
    escrow.createProject(
        "Build Website",
        "Create ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(client);
    escrow.createMilestone(
        1,
        "UI Design",
        0.3 ether
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(client);
    escrow.fundProject{value: 1 ether}(1);

    vm.prank(freelancer);
    escrow.submitMilestone(1, 1);

    vm.prank(client);
    escrow.approveMilestone(1, 1);

    uint256 balanceBefore =
        freelancer.balance;

    vm.prank(client);
    escrow.payMilestone(1, 1);

    uint256 balanceAfter =
        freelancer.balance;

    assertEq(
    balanceAfter,
    balanceBefore + 0.285 ether
);

}

function testOnlyClientCanPayMilestone()
    public
{
    vm.prank(client);
    escrow.createProject(
        "Build Website",
        "Create ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(client);
    escrow.createMilestone(
        1,
        "UI Design",
        0.3 ether
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(client);
    escrow.fundProject{value: 1 ether}(1);

    vm.prank(freelancer);
    escrow.submitMilestone(1, 1);

    vm.prank(client);
    escrow.approveMilestone(1, 1);

    vm.expectRevert();

    vm.prank(freelancer);
    escrow.payMilestone(1, 1);
}

function testPlatformFeeCollected()
    public
{
    vm.prank(client);

    escrow.createProject(
        "Build Website",
        "Create ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(client);
    escrow.createMilestone(
        1,
        "UI Design",
        0.3 ether
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(client);
    escrow.fundProject{value: 1 ether}(1);

    vm.prank(freelancer);
    escrow.submitMilestone(1, 1);

    vm.prank(client);
    escrow.approveMilestone(1, 1);

    vm.prank(client);
    escrow.payMilestone(1, 1);

    assertEq(
        escrow.getPlatformBalance(),
        0.015 ether
    );
}

function testCannotExceedProjectBudgetWithMilestones()
    public
{
    vm.prank(client);

    escrow.createProject(
        "Build Website",
        "Create ecommerce website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(client);
    escrow.createMilestone(
        1,
        "UI Design",
        0.6 ether
    );

    vm.prank(client);
    escrow.createMilestone(
        1,
        "Frontend",
        0.4 ether
    );

    vm.expectRevert();

    vm.prank(client);
    escrow.createMilestone(
        1,
        "Backend",
        0.1 ether
    );
}

function testOwnerIsDeployer()
    public
{
    assertEq(
        escrow.getOwner(),
        address(this)
    );
}

function testWithdrawPlatformFees()
    public
{
    vm.prank(client);
    escrow.createProject(
        "Website",
        "Build website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(client);
    escrow.createMilestone(
        1,
        "UI Design",
        0.3 ether
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(client);
    escrow.fundProject{value: 1 ether}(1);

    vm.prank(freelancer);
    escrow.submitMilestone(1, 1);

    vm.prank(client);
    escrow.approveMilestone(1, 1);

    vm.prank(client);
    escrow.payMilestone(1, 1);

    assertEq(
        escrow.getPlatformBalance(),
        0.015 ether
    );

    uint256 ownerBalanceBefore =
    address(this).balance;
    escrow.withdrawPlatformFees();
    uint256 ownerBalanceAfter =
    address(this).balance;
    assertEq(
        escrow.getPlatformBalance(),
        0
    );
    assertEq(
    ownerBalanceAfter,
    ownerBalanceBefore + 0.015 ether
);
}

function testOnlyOwnerCanWithdrawPlatformFees()
    public
{
    vm.prank(client);
    escrow.createProject(
        "Website",
        "Build website",
        1 ether,
        block.timestamp + 30 days
    );

    vm.prank(client);
    escrow.createMilestone(
        1,
        "UI Design",
        0.3 ether
    );

    vm.prank(freelancer);
    escrow.acceptProject(1);

    vm.prank(client);
    escrow.fundProject{value: 1 ether}(1);

    vm.prank(freelancer);
    escrow.submitMilestone(1, 1);

    vm.prank(client);
    escrow.approveMilestone(1, 1);

    vm.prank(client);
    escrow.payMilestone(1, 1);

    vm.expectRevert();

    vm.prank(client);
    escrow.withdrawPlatformFees();
}


}