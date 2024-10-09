// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract GovernanceToken is ERC20, ERC20Burnable, ReentrancyGuard, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");
    bytes32 public constant VESTER_ROLE = keccak256("VESTER_ROLE");

    mapping(address => address) public delegates;
    mapping(address => uint256) public lockupEnd;
    mapping(address => uint256) public vestingStart;
    mapping(address => uint256) public vestedAmount;

    event DelegateChanged(address indexed delegator, address indexed to);
    event TokensLocked(address indexed holder, uint256 unlockTime);

    error TokensLockedError(uint256 unlockTime);
    error InsufficientBalance(uint256 available, uint256 required);

    constructor() ERC20("GovernanceToken", "GT") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(LOCKER_ROLE, msg.sender);
        _grantRole(VESTER_ROLE, msg.sender);
    }

    function mintTokens(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function transfer(address to, uint256 amount) public override nonReentrant returns (bool) {
        if (lockupEnd[msg.sender] > block.timestamp) {
            revert TokensLockedError(lockupEnd[msg.sender]);
        }

        uint256 senderBalance = balanceOf(msg.sender);
        if (senderBalance < amount) {
            revert InsufficientBalance(senderBalance, amount);
        }

        _transfer(msg.sender, to, amount);
        return true;
    }

    function balanceOf(address owner) public view override returns (uint256) {
        return super.balanceOf(owner);
    }

    function delegateVotingPower(address to) public {
        delegates[msg.sender] = to;
        emit DelegateChanged(msg.sender, to);
    }

    function lockTokens(uint256 duration) public onlyRole(LOCKER_ROLE) {
        lockupEnd[msg.sender] = block.timestamp + duration;
        emit TokensLocked(msg.sender, lockupEnd[msg.sender]);
    }

    function vestTokens(address to, uint256 amount) public onlyRole(VESTER_ROLE) {
        vestedAmount[to] += amount;
        vestingStart[to] = block.timestamp;
    }

    function releaseVestedTokens() public nonReentrant {
        require(vestedAmount[msg.sender] > 0, "No tokens to release");
        uint256 amount = vestedAmount[msg.sender];
        vestedAmount[msg.sender] = 0;
        _mint(msg.sender, amount);
        emit Transfer(address(0), msg.sender, amount);
    }
}

contract DAIPGovernance {
    struct Proposal {
        address proposer;
        address target;
        uint256 value;
        bytes data;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        uint256 expiration;
        string category;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    GovernanceToken public token;

    event ProposalCreated(uint256 proposalId, address proposer);
    event VoteCast(address voter, uint256 proposalId, bool support);
    event ProposalExecuted(uint256 proposalId);

    error ProposalNotExists(uint256 proposalId);
    error AlreadyExecuted(uint256 proposalId);
    error ProposalDidNotPass(uint256 votesFor, uint256 votesAgainst);
    error ExecutionFailed();

    constructor(address tokenAddress) {
        token = GovernanceToken(tokenAddress);
        proposalCount = 0;
    }

    function createProposal(address target, uint256 value, bytes memory data, string memory category)
        public
        returns (uint256)
    {
        proposalCount++;
        proposals[proposalCount] =
            Proposal(msg.sender, target, value, data, 0, 0, false, block.timestamp + 7 days, category);
        emit ProposalCreated(proposalCount, msg.sender);
        return proposalCount;
    }

    function voteOnProposal(uint256 proposalId, bool support) public {
        if (proposals[proposalId].proposer == address(0)) {
            revert ProposalNotExists(proposalId);
        }

        if (block.timestamp > proposals[proposalId].expiration) {
            revert ProposalNotExists(proposalId); // Proposal expired
        }

        uint256 votes = token.balanceOf(msg.sender);

        if (support) {
            proposals[proposalId].votesFor += votes;
        } else {
            proposals[proposalId].votesAgainst += votes;
        }

        emit VoteCast(msg.sender, proposalId, support);
    }

    function executeProposal(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.proposer == address(0)) revert ProposalNotExists(proposalId);

        if (proposal.executed) revert AlreadyExecuted(proposalId);

        if (block.timestamp > proposal.expiration) revert ProposalNotExists(proposalId);

        if (proposal.votesFor <= proposal.votesAgainst) {
            revert ProposalDidNotPass(proposal.votesFor, proposal.votesAgainst);
        }

        (bool success,) = proposal.target.call{value: proposal.value}(proposal.data);

        if (!success) revert ExecutionFailed();

        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

    function getProposal(uint256 proposalId) public view returns (Proposal memory) {
        return proposals[proposalId];
    }

    function getProposals() public view returns (Proposal[] memory) {
        Proposal[] memory proposalList = new Proposal[](proposalCount);

        for (uint256 i = 1; i <= proposalCount; i++) {
            proposalList[i - 1] = proposals[i];
        }

        return proposalList;
    }
}
