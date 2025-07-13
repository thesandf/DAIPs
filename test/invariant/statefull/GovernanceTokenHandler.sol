// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/GovernanceToken.sol";

contract GovernanceTokenHandler {
    GovernanceToken public token;
    address[] public users;

    constructor(GovernanceToken _token) {
        token = _token;

        // Create some user addresses (e.g. A, B, C)
        for (uint160 i = 1; i <= 5; i++) {
            users.push(address(i));
        }

        // Grant roles to admin
        for (uint256 i = 0; i < users.length; i++) {
            token.grantRole(token.MINTER_ROLE(), users[i]);
            token.grantRole(token.LOCKER_ROLE(), users[i]);
            token.grantRole(token.VESTER_ROLE(), users[i]);
        }
    }

    function mintTokens(uint256 userIndex, uint256 amount) public {
        address user = users[userIndex % users.length];
        amount = bound(amount, 1 ether, 1_000 ether);
        vm.prank(user);
        token.mintTokens(user, amount);
    }

    function delegate(uint256 fromIndex, uint256 toIndex) public {
        address from = users[fromIndex % users.length];
        address to = users[toIndex % users.length];
        vm.prank(from);
        token.delegateVotingPower(to);
    }

    function createProposal(uint256 proposerIndex, uint256 targetIndex, uint8 categoryRaw) public {
        address proposer = users[proposerIndex % users.length];
        address target = users[targetIndex % users.length];
        GovernanceToken.Category category = GovernanceToken.Category(categoryRaw % 3);
        bytes memory data = "";
        string memory description = "ipfs://dao-proposal";
        vm.prank(proposer);
        token.createProposal(target, 0, data, category, description);
    }

    function vote(uint256 voterIndex, uint256 proposalId, bool support) public {
        address voter = users[voterIndex % users.length];
        vm.prank(voter);
        try token.voteOnProposal(proposalId % token.proposalCount() + 1, support) {} catch {}
    }

    function releaseVesting(uint256 userIndex) public {
        address user = users[userIndex % users.length];
        vm.prank(user);
        try token.releaseVestedTokens() {} catch {}
    }

    function cancelProposal(uint256 userIndex, uint256 proposalId) public {
        address user = users[userIndex % users.length];
        vm.prank(user);
        try token.cancelProposal(proposalId % token.proposalCount() + 1) {} catch {}
    }

    function lockUser(uint256 lockerIndex, uint256 userIndex, uint256 duration) public {
        address locker = users[lockerIndex % users.length];
        address target = users[userIndex % users.length];
        duration = bound(duration, 1 days, 30 days);
        vm.prank(locker);
        try token.lockTokens(target, duration) {} catch {}
    }
}
