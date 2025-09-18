// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library LibErrors {
    error OwnableInvalidOwner(addres owner);
    error InvalidSender(address sender);
    error InvalidReceiver(address receiver);
    error InsufficientBalance(address from, uint256 balance, uint256 needed);
    error InvalidApprover(address approver);
    error InvalidSpender(address spender);
    error InsufficientAllowance(address spender, uint256 current, uint256 needed);

    // ========== Access Control ==========
    error Unauthorized(address sender, bytes32 role);
    error InvalidConfirmation();

    // ========== Errors Of GovernanceTokenFacet ==========
    error NotAdmin();
    error TokensLockedError(uint256 unlockTime);
    error InsufficientBalance(uint256 available, uint256 required);
    error ProposalNotExists(uint256 proposalId);
    error ProposalExpired(uint256 current, uint256 expiration);
    error AlreadyExecuted(uint256 proposalId);
    error NoVotingPower(address voter);
    error AlreadyVoted();
    error ProposalDidNotPass(uint256 votesFor, uint256 votesAgainst);
    error ExecutionFailed();
    error ProposalAutoExecutionFailedForUpgradeProposal(uint256 proposalId);
    error OnlySelfCallAllowed();
    error NoVestingSchedule();
    error ZeroAmount();
    error ZeroDuration();
    error InvalidCliffDuration(uint256 duration, uint256 cliff);
    error TimelockNotExpired(uint256 current, uint256 required);
    error AlreadyVesting(address beneficiary);
    error NotRevocable();
    error Error__VestingRevoked();
    error NoTokensToRelease();
    error NotEnoughVotes(uint256 total, uint256 required);
    error NotAuthorizedToCancelThisProposal(address caller);

}
