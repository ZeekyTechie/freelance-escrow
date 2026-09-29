// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/ChainEscrow.sol";

contract ChainEscrowTest is Test {

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

}