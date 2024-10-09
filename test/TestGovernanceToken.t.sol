// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {DAIPGovernance, GovernanceToken} from "../src/GovernanceToken.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken public governanceToken;
    DAIPGovernance public daipGovernance;

    address public deployer;
    address public user1;
    address public user2;
    address public user3;

    function setUp() public {
        deployer = vm.addr(1);
        user1 = vm.addr(2);
        user2 = vm.addr(3);
        user3 = vm.addr(4);
        vm.deal(deployer, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.startPrank(deployer);
        governanceToken = new GovernanceToken();
        daipGovernance = new DAIPGovernance(address(governanceToken));
        vm.stopPrank();
    }

    function testMintTokens() public {
        vm.startPrank(deployer);

        governanceToken.mintTokens(user1, 1000 * 10 ** governanceToken.decimals());
        assertEq(governanceToken.balanceOf(user1), 1000 * 10 ** governanceToken.decimals());

        governanceToken.mintTokens(user2, 500 * 10 ** governanceToken.decimals());
        assertEq(governanceToken.balanceOf(user2), 500 * 10 ** governanceToken.decimals());

        vm.stopPrank();
    }

    function testAssignRoles() public {
        vm.startPrank(deployer);

        governanceToken.grantRole(governanceToken.MINTER_ROLE(), user1);
        governanceToken.grantRole(governanceToken.LOCKER_ROLE(), user1);
        governanceToken.grantRole(governanceToken.VESTER_ROLE(), user1);

        assertTrue(governanceToken.hasRole(governanceToken.MINTER_ROLE(), user1));
        assertTrue(governanceToken.hasRole(governanceToken.LOCKER_ROLE(), user1));
        assertTrue(governanceToken.hasRole(governanceToken.VESTER_ROLE(), user1));

        vm.stopPrank();
    }

    // Test Locking Tokens
    function testLockTokens() public {
        vm.startPrank(deployer);

        governanceToken.mintTokens(user1, 1000 * 10 ** governanceToken.decimals());
        governanceToken.grantRole(governanceToken.LOCKER_ROLE(), user1);

        vm.stopPrank();
        vm.startPrank(user1);

        governanceToken.lockTokens(7 days);
        assertTrue(governanceToken.lockupEnd(user1) > block.timestamp);

        vm.stopPrank();
    }

    // Test Vesting Tokens
    // Test Vesting Tokens
    function testVestTokens() public {
        vm.startPrank(deployer);

        governanceToken.mintTokens(user2, 2000 * 10 ** governanceToken.decimals());
        governanceToken.grantRole(governanceToken.VESTER_ROLE(), deployer);

        governanceToken.vestTokens(user2, 1000 * 10 ** governanceToken.decimals());

        uint256 vestedAmount = governanceToken.vestedAmount(user2);
        assertEq(vestedAmount, 1000 * 10 ** governanceToken.decimals());

        vm.startPrank(user2);
        governanceToken.releaseVestedTokens();
        vm.stopPrank();

        vm.stopPrank();
    }

    // Test Transferring Tokens
    function testTransferTokens() public {
        vm.startPrank(deployer);

        governanceToken.mintTokens(user1, 500 * 10 ** governanceToken.decimals());
        vm.stopPrank();
        vm.startPrank(user1);

        governanceToken.transfer(user2, 250 * 10 ** governanceToken.decimals());
        assertEq(governanceToken.balanceOf(user2), 250 * 10 ** governanceToken.decimals());
        assertEq(governanceToken.balanceOf(user1), 250 * 10 ** governanceToken.decimals());

        vm.stopPrank();
    }

    // Test Proposal Creation, Voting, and Execution in DAIPGovernance
    function testProposalCreationVotingExecution() public {
        vm.startPrank(deployer);

        governanceToken.mintTokens(user1, 1000 * 10 ** governanceToken.decimals());
        governanceToken.mintTokens(user2, 500 * 10 ** governanceToken.decimals());
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 proposalId = daipGovernance.createProposal(
            address(this), 0, abi.encodeWithSignature("dummyFunction()"), "Proposal to Test Governance"
        );
        vm.stopPrank();

        // User1 and User2 vote on the proposal
        vm.startPrank(user1);
        daipGovernance.voteOnProposal(proposalId, true); // vote in favor
        vm.stopPrank();

        vm.startPrank(user2);
        daipGovernance.voteOnProposal(proposalId, false); // vote against
        vm.stopPrank();

        // Validate voting outcome
        DAIPGovernance.Proposal memory proposal = daipGovernance.getProposal(proposalId);
        assertEq(proposal.votesFor, 1000 * 10 ** governanceToken.decimals());
        assertEq(proposal.votesAgainst, 500 * 10 ** governanceToken.decimals());

        vm.warp(block.timestamp + 7 days);

        vm.startPrank(user1);
        daipGovernance.executeProposal(proposalId);
        vm.stopPrank();
    }

    // Dummy function for proposal execution
    function dummyFunction() public pure returns (string memory) {
        return "Executed successfully";
    }

    function testProposalExecutionRevert() public {
        vm.startPrank(deployer);

        governanceToken.mintTokens(user3, 2000 * 10 ** governanceToken.decimals());
        vm.stopPrank();
        vm.startPrank(user3);
        uint256 proposalId =
            daipGovernance.createProposal(address(this), 0, abi.encodeWithSignature("dummyFunction()"), "Test Revert");
        vm.stopPrank();

        vm.warp(block.timestamp + 8 days);

        vm.expectRevert(abi.encodeWithSignature("ProposalNotExists(uint256)", proposalId)); // Adjust the expected revert
        vm.startPrank(user3);
        daipGovernance.executeProposal(proposalId);
        vm.stopPrank();
    }
}
