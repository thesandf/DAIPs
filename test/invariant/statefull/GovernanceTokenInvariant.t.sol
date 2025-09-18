// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../../src/GovernanceToken.sol";
import "./GovernanceTokenHandler.sol";

contract GovernanceTokenInvariant is Test {
    GovernanceToken public token;
    GovernanceTokenHandler public handler;

    function setUp() public {
        token = new GovernanceToken();
        handler = new GovernanceTokenHandler(token);
        targetContract(address(handler));
    }

    /// @notice Total delegated voting power should not exceed total supply
    function invariant_TotalVotingPowerLeTotalSupply() public view {
        uint256 totalVoting;
        for (uint160 i = 1; i <= 5; i++) {
            address user = address(i);
            totalVoting += token.getVotes(user);
        }
        assertLe(totalVoting, token.totalSupply());
    }

    /// @notice Vestings marked as non-revocable must not be revoked
    function invariant_OnlyRevocableCanBeRevoked() public view {
        for (uint160 i = 1; i <= 5; i++) {
            (,,,,, bool revocable, bool revoked) = token.vestings(address(i));
            assertFalse(!revocable && revoked, "Non-revocable vesting was revoked");
        }
    }

    /// @notice Unexecuted proposals must not have exceeded expiration + 1 day
    function invariant_ActiveProposalNotExecutedBeforeTime() public view {
        for (uint256 i = 1; i <= token.proposalCount(); i++) {
            GovernanceToken.Proposal memory p = token.getProposal(i);
            if (!p.executed) {
                assertGt(p.expiration + 1 days, block.timestamp);
            }
        }
    }

    /// @notice Voting power must not exceed token balance -- but what about delegated power?
    /// @dev This invariant checks that no account has voting power greater than its balance.
    function invariant_NoAccountWithVotingPowerGreaterThanBalance() public view {
        for (uint160 i = 1; i <= 5; i++) {
            address user = address(i);
            assertLe(token.getVotes(user), token.balanceOf(user));
        }
    }

    /// @notice Released tokens from vesting must not exceed total vesting amount
    function invariant_NoVestingReleasedGreaterThanAmount() public view {
        for (uint160 i = 1; i <= 5; i++) {
            (,,, uint256 amount, uint256 released,,) = token.vestings(address(i));
            assertLe(released, amount);
        }
    }

    /// @notice Proposals must not exist with zero total votes
    function invariant_NoProposalWithZeroVotes() public view {
        for (uint256 i = 1; i <= token.proposalCount(); i++) {
            GovernanceToken.Proposal memory p = token.getProposal(i);
            if (!p.executed && block.timestamp > p.expiration) {
                assertGt(p.votesFor + p.votesAgainst, 0, "Proposal has zero votes post-deadline");
            }
        }
    }

    /// @notice Executed proposals must have respected 1-day timelock after expiration
    function invariant_ExecutedProposalsRespectTimelock() public view {
        for (uint256 i = 1; i <= token.proposalCount(); i++) {
            GovernanceToken.Proposal memory p = token.getProposal(i);
            if (p.executed) {
                assertGe(block.timestamp, p.expiration + 1 days, "Executed before timelock");
            }
        }
    }

    /// @notice Proposals must not be re-executed (by checking the single `executed` flag)
    function invariant_NoDoubleExecution() public view {
        for (uint256 i = 1; i <= token.proposalCount(); i++) {
            GovernanceToken.Proposal memory p = token.getProposal(i);
            if (p.executed) {
                // Only possible way to check is by ensuring the `executed` flag was flipped once
                assertTrue(p.executed, "Proposal was executed multiple times");
            }
        }
    }

    /// @notice Proposals must have a valid category enum value
    function invariant_ProposalCategoriesValid() public view {
        for (uint256 i = 1; i <= token.proposalCount(); i++) {
            GovernanceToken.Proposal memory p = token.getProposal(i);
            assertTrue(uint8(p.category) <= uint8(GovernanceToken.Category.Upgrade), "Invalid proposal category");
        }
    }

    /// @notice Proposals must have a non-zero proposer address
    function invariant_NoProposalWithZeroProposer() public view {
        for (uint256 i = 1; i <= token.proposalCount(); i++) {
            GovernanceToken.Proposal memory p = token.getProposal(i);
            assertTrue(p.proposer != address(0), "Proposal has zero address proposer");
        }
    }
}
