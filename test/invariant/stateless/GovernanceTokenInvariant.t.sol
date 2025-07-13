// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {GovernanceToken} from "src/GovernanceToken.sol";

contract GovernanceToken_StatelessFuzz is Test {
    GovernanceToken public token;
    address admin = makeAddr("admin");
    address user = makeAddr("user");

    function setUp() public {
        vm.startPrank(admin);
        token = new GovernanceToken();
        vm.stopPrank();

        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), admin);
        token.grantRole(token.LOCKER_ROLE(), admin);
        token.grantRole(token.VESTER_ROLE(), admin);
        token.grantRole(token.ADMIN_ROLE(), admin);
        vm.stopPrank();
    }

    function testFuzz_MintTokens(address to, uint256 amount) public {
        amount = bound(amount, 1, 1e24);
        to = address(uint160(bound(uint160(to), 1, type(uint160).max))); // Avoid address(0)
        uint256 supplyBefore = token.totalSupply();
        vm.prank(admin);
        token.mintTokens(to, amount);
        assertEq(token.totalSupply(), supplyBefore + amount);
        assertEq(token.balanceOf(to), amount);
    }

    function testFuzz_DelegateVoting(address to, uint256 amount) public {
        amount = bound(amount, 1, 1e24);

        vm.prank(admin);
        token.mintTokens(user, amount);

        vm.prank(user);
        token.delegateVotingPower(to);

        assertEq(token.getVotes(to), amount);
    }

    function testFuzz_TransferRespectsLock(address recipient, uint256 amount) public {
        amount = bound(amount, 1, 1e24);
        vm.startPrank(admin);
        token.mintTokens(admin, amount);
        token.lockTokens(admin, 1 days);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert();
        token.transfer(recipient, amount);
    }

    function testFuzz_VestTokensAndRelease(address beneficiary, uint256 amount, uint256 timeOffset) public {
        amount = bound(amount, 1, 1e24);
        timeOffset = bound(timeOffset, 0, 52 weeks);

        uint256 start = block.timestamp;
        uint256 cliff = 1 days;
        uint256 duration = 7 days;

        vm.prank(admin);
        token.vestTokens(beneficiary, amount, start, cliff, duration, true);

        vm.warp(start + timeOffset);

        vm.startPrank(beneficiary);
        try token.releaseVestedTokens() {
            uint256 vested = token.balanceOf(beneficiary);
            assertGt(vested, 0);
            assertLe(vested, amount);
        } catch {
            // allowed to fail if not past cliff or nothing vested
        }
        vm.stopPrank();
    }

    function testFuzz_ProposalCreation(address target, uint256 value, bytes memory data, uint8 category) public {
        string memory ipfs = "ipfs://example";
        category = uint8(bound(category, 0, 2));
        uint256 pid = token.createProposal(target, value, data, GovernanceToken.Category(category), ipfs);
        GovernanceToken.Proposal memory p = token.getProposal(pid);
        assertEq(p.proposer, address(this));
        assertEq(p.target, target);
    }

    function testFuzz_CannotVoteWithoutPower(address voter, bool support) public {
        vm.prank(voter);
        vm.expectRevert();
        token.voteOnProposal(1, support);
    }
}
