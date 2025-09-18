// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IGovernanceTokenFacet
 * @dev Interface for all GovernanceToken functions (for Diamond Standard).
 */
interface IGovernanceTokenFacet {

    struct Proposal {
    address proposer;
    address target;
    uint256 value;
    bytes data;
    uint256 votesFor;
    uint256 votesAgainst;
    bool executed;
    uint256 expiration;
    uint8 category;
    string descriptionHash;
   }
   
    // ========== Token Mechanics ==========
    function mintTokens(address to, uint256 amount) external;
    function transfer(address to, uint256 amount) external returns (bool);
    function delegateVotingPower(address to) external;
    function lockTokens(address user, uint256 duration) external;
    // ========== Vesting ==========
    function vestTokens(address beneficiary, uint256 amount, uint256 start, uint256 cliff, uint256 duration, bool revocable) external;
    function releaseVestedTokens() external;
    function revokeVesting(address beneficiary) external;
    // ========== Governance ==========
    function createProposal(address target, uint256 value, bytes calldata data, uint8 category, string calldata descriptionHash) external returns (uint256);
    function voteOnProposal(uint256 proposalId, bool support) external;
    function executeProposal(uint256 proposalId) external;
    function autoExecuteProposals() external;
    function cancelProposal(uint256 proposalId) external;
    // ========== Admin Utilities ==========
    function grantAdminRole(address account) external;
    function revokeAdminRole(address account) external;
    function transferAdminRole(address newAdmin) external;
    // ========== View Utilities ==========
    function getQuorumPercentage(uint8 category) external pure returns (uint256);
    function getVotes(address account) external view returns (uint256);
    function getProposal(uint256 proposalId) external view returns (Proposal memory);
    function getProposals() external view returns (Proposal[] memory);
    function setQueuedAt(uint256 proposalId, uint256 timestamp) external;
    // ========== ERC20 ==========
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
