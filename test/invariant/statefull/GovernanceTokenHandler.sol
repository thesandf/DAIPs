// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../../src/GovernanceToken.sol";

contract GovernanceTokenHandler is Test {
    GovernanceToken public token;
    address[] public users;

    constructor(GovernanceToken _token) {
        token = _token;

        // Simulate 5 users (e.g., address(1) to address(5))
        for (uint160 i = 1; i <= 5; i++) {
            users.push(address(i));
        }
    }

    /// @notice Mint tokens to a user
    function mintTokens(uint256 userIndex, uint256 amount) public {
        address user = users[userIndex % users.length];
        amount = bound(amount, 1 ether, 1_000 ether);
        token.mintTokens(user, amount);
    }

    /// @notice Delegate voting power
    function delegate(uint256 fromIndex, uint256 toIndex) public {
        address from = users[fromIndex % users.length];
        address to = users[toIndex % users.length];
        vm.prank(from);
        token.delegateVotingPower(to);
    }

    /// @notice Create a governance proposal
    function createProposal(uint256 proposerIndex, uint256 targetIndex, uint8 categoryRaw) public {
        address proposer = users[proposerIndex % users.length];
        address target = users[targetIndex % users.length];
        GovernanceToken.Category category = GovernanceToken.Category(categoryRaw % 3); // General, Treasury, Upgrade
        bytes memory data = "";
        string memory description = "ipfs://dao-proposal";
        vm.prank(proposer);
        try token.createProposal(target, 0, data, category, description) {} catch {}
    }

    /// @notice Vote on an existing proposal
    function vote(uint256 voterIndex, uint256 proposalId, bool support) public {
        address voter = users[voterIndex % users.length];
        vm.prank(voter);
        try token.voteOnProposal(proposalId % token.proposalCount() + 1, support) {} catch {}
    }

    /// @notice Execute a proposal after it has passed
    function executeProposal(uint256 proposalId) public {
        try token.executeProposal(proposalId % token.proposalCount() + 1) {} catch {}
    }

    /// @notice Cancel an active proposal
    function cancelProposal(uint256 userIndex, uint256 proposalId) public {
        address user = users[userIndex % users.length];
        vm.prank(user);
        try token.cancelProposal(proposalId % token.proposalCount() + 1) {} catch {}
    }

    /// @notice Create a vesting schedule for a user
    function createVesting(uint256 toIndex, uint256 amount, bool revocable) public {
        address user = users[toIndex % users.length];
        amount = bound(amount, 1 ether, 100 ether);
        uint256 start = block.timestamp;
        uint256 cliff = start + 1 days;
        uint256 duration = 30 days;

        try token.vestTokens(user, start, cliff, duration, amount, revocable) {} catch {}
    }

    /// @notice Release vested tokens for a user
    function releaseVesting(uint256 userIndex) public {
        address user = users[userIndex % users.length];
        vm.prank(user);
        try token.releaseVestedTokens() {} catch {}
    }

    /// @notice Revoke an active vesting schedule (admin-only)
    function revokeVesting(uint256 adminIndex, uint256 targetIndex) public {
        address admin = users[adminIndex % users.length];
        address target = users[targetIndex % users.length];
        vm.prank(admin);
        try token.revokeVesting(target) {} catch {}
    }

    /// @notice Transfer tokens between users
    function transfer(uint256 fromIndex, uint256 toIndex, uint256 amount) public {
        address from = users[fromIndex % users.length];
        address to = users[toIndex % users.length];
        amount = bound(amount, 0, token.balanceOf(from));
        vm.prank(from);
        try token.transfer(to, amount) {} catch {}
    }

    /// @notice Lock a user's tokens for a duration (admin or locker role)
    function lockUser(uint256 lockerIndex, uint256 userIndex, uint256 duration) public {
        address locker = users[lockerIndex % users.length];
        address target = users[userIndex % users.length];
        duration = bound(duration, 1 days, 30 days);
        vm.prank(locker);
        try token.lockTokens(target, duration) {} catch {}
    }
}
