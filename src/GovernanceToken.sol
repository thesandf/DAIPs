// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title GovernanceToken
/// @notice ERC20 governance token with voting delegation, proposal execution, and vesting mechanisms.
/// @dev Designed for use within the DAIP platform governance system.
contract GovernanceToken is ERC20, ReentrancyGuard, AccessControl {
    // ========== Role Definitions ==========
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");
    bytes32 public constant VESTER_ROLE = keccak256("VESTER_ROLE");

    // ========== Constants ==========
    uint256 public constant EXECUTION_DELAY = 1 days;
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    // ========== Enums ==========
    enum Category {
        General,
        Treasury,
        Upgrade
    }

    // ========== State Variables ==========
    uint256 public proposalCount;

    struct VestingSchedule {
        uint256 start;
        uint256 cliff;
        uint256 duration;
        uint256 amount;
        uint256 released;
        bool revocable;
        bool revoked;
    }

    struct Proposal {
        address proposer;
        address target;
        uint256 value;
        bytes data;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        uint256 expiration;
        Category category;
        string descriptionHash;
    }

    // ========== Mappings ==========
    mapping(address => address) public delegates;
    mapping(address => uint256) public votingPower;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => uint256) public queuedAt;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => VestingSchedule) public vestings;
    mapping(address => uint256) public lockupEnd;

    // ========== Events ==========
    event DelegateChanged(address indexed delegator, address indexed to);
    event TokensLocked(address indexed holder, uint256 unlockTime);
    event ProposalCreated(uint256 indexed proposalId, address proposer);
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalAutoExecutionFailed(uint256 indexed proposalId, string reason);
    event ProposalCancelled(uint256 indexed proposalId);
    event UpgradeExecutionBlocked(uint256 proposalId);
    event VestingGranted(
        address indexed beneficiary, uint256 amount, uint256 start, uint256 cliff, uint256 duration, bool revocable
    );
    event VestingRevoked(address indexed beneficiary);
    event VestedTokensReleased(address indexed beneficiary, uint256 amount);

    // ========== Errors ==========
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

    // ========== Constructor ==========
    /// @notice Deploys the contract, mints initial supply, and assigns all roles to the deployer.
    constructor() ERC20("GovernanceTokenForDAIP", "GT-5") {
        _mint(msg.sender, INITIAL_SUPPLY);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(LOCKER_ROLE, msg.sender);
        _grantRole(VESTER_ROLE, msg.sender);
        delegates[msg.sender] = msg.sender;
        votingPower[msg.sender] = totalSupply();
    }

    // ========== Token Mechanics ==========

    /// @notice Mints new tokens to an address.
    /// @param to Recipient address.
    /// @param amount Amount of tokens to mint.
    function mintTokens(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
        address delegatee = delegates[to] == address(0) ? to : delegates[to];
        _moveVotingPower(address(0), delegatee, amount);
    }

    /// @notice Transfers tokens and updates voting power.
    /// @dev Enforces token lockup.
    function transfer(address to, uint256 amount) public override nonReentrant returns (bool) {
        if (lockupEnd[msg.sender] > block.timestamp) {
            revert TokensLockedError(lockupEnd[msg.sender]);
        }
        uint256 senderBalance = balanceOf(msg.sender);
        if (senderBalance < amount) revert InsufficientBalance(senderBalance, amount);
        _transfer(msg.sender, to, amount);
        _afterTokenTransfer(msg.sender, to, amount);
        return true;
    }

    /// @dev Hook that updates delegated voting power after token transfers.
    /// @param from The address tokens are transferred from.
    /// @param to The address tokens are transferred to.
    /// @param amount The amount of tokens transferred.
    function _afterTokenTransfer(address from, address to, uint256 amount) internal {
        address fromDelegate = delegates[from] == address(0) ? from : delegates[from];
        address toDelegate = delegates[to] == address(0) ? to : delegates[to];
        _moveVotingPower(fromDelegate, toDelegate, amount);
    }

    /// @dev Internal function to adjust voting power between delegates.
    /// @param from The address losing voting power.
    /// @param to The address gaining voting power.
    /// @param amount The number of tokens to adjust.
    function _moveVotingPower(address from, address to, uint256 amount) internal {
        if (amount > 0) {
            if (from != address(0)) votingPower[from] -= amount;
            if (to != address(0)) votingPower[to] += amount;
        }
    }

    /// @notice Delegates voting power to another address.
    /// @param to Address to delegate to.
    function delegateVotingPower(address to) public {
        address previous = delegates[msg.sender];
        uint256 balance = balanceOf(msg.sender);
        _moveVotingPower(previous == address(0) ? msg.sender : previous, to, balance);
        delegates[msg.sender] = to;
        emit DelegateChanged(msg.sender, to);
    }

    /// @notice Locks tokens for a user for a specified duration.
    /// @param user The address to lock tokens for.
    /// @param duration Lock duration in seconds.
    function lockTokens(address user, uint256 duration) public onlyRole(LOCKER_ROLE) {
        uint256 unlockTime = block.timestamp + duration;
        lockupEnd[user] = unlockTime;
        emit TokensLocked(user, unlockTime);
    }

    // ========== Vesting ==========

    /// @notice Grants a vesting schedule to a beneficiary.
    /// @param beneficiary Address to receive tokens.
    /// @param amount Total amount to vest.
    /// @param start Start timestamp.
    /// @param cliff Cliff duration in seconds.
    /// @param duration Total duration in seconds.
    /// @param revocable Whether the vesting is revocable.
    function vestTokens(
        address beneficiary,
        uint256 amount,
        uint256 start,
        uint256 cliff,
        uint256 duration,
        bool revocable
    ) public onlyRole(VESTER_ROLE) {
        if (amount == 0) revert ZeroAmount();
        if (duration == 0) revert ZeroDuration();
        if (duration < cliff) revert InvalidCliffDuration(duration, cliff);
        if (vestings[beneficiary].amount != 0 && !vestings[beneficiary].revoked) {
            revert AlreadyVesting(beneficiary);
        }

        vestings[beneficiary] = VestingSchedule({
            start: start,
            cliff: cliff,
            duration: duration,
            amount: amount,
            released: 0,
            revocable: revocable,
            revoked: false
        });

        if (cliff > 0) {
            uint256 unlockTime = start + cliff;
            lockupEnd[beneficiary] = unlockTime;
            emit TokensLocked(beneficiary, unlockTime);
        }

        emit VestingGranted(beneficiary, amount, start, cliff, duration, revocable);
    }

    /// @notice Releases vested tokens to the caller.
    function releaseVestedTokens() public nonReentrant {
        VestingSchedule storage vesting = vestings[msg.sender];
        if (vesting.amount == 0) revert NoVestingSchedule();
        if (vesting.revoked) revert Error__VestingRevoked();

        uint256 vested = _vestedAmount(vesting);
        uint256 unreleased = vested - vesting.released;
        if (unreleased == 0) revert NoTokensToRelease();

        vesting.released += unreleased;
        _mint(msg.sender, unreleased);

        address delegatee = delegates[msg.sender] == address(0) ? msg.sender : delegates[msg.sender];
        votingPower[delegatee] += unreleased;

        emit VestedTokensReleased(msg.sender, unreleased);
    }

    /// @notice Revokes a vesting schedule.
    /// @param beneficiary The beneficiary to revoke.
    function revokeVesting(address beneficiary) public onlyRole(VESTER_ROLE) {
        VestingSchedule storage vesting = vestings[beneficiary];
        if (!vesting.revocable) revert NotRevocable();
        if (vesting.revoked) revert Error__VestingRevoked();
        vesting.revoked = true;
        emit VestingRevoked(beneficiary);
    }

    /// @dev Calculates the vested amount for a schedule.
    /// @param vesting VestingSchedule struct.
    /// @return Amount of tokens vested.
    function _vestedAmount(VestingSchedule memory vesting) internal view returns (uint256) {
        if (block.timestamp < vesting.start + vesting.cliff) return 0;
        if (block.timestamp >= vesting.start + vesting.duration || vesting.revoked) return vesting.amount;
        return (vesting.amount * (block.timestamp - vesting.start)) / vesting.duration;
    }

    // ========== Governance ==========

    /// @notice Creates a new proposal.
    /// @param target Address to call.
    /// @param value ETH to send.
    /// @param data Call data.
    /// @param category Proposal category.
    /// @param descriptionHash IPFS hash of description.
    function createProposal(
        address target,
        uint256 value,
        bytes memory data,
        Category category,
        string memory descriptionHash
    ) public returns (uint256) {
        proposalCount++;
        proposals[proposalCount] = Proposal({
            proposer: msg.sender,
            target: target,
            value: value,
            data: data,
            votesFor: 0,
            votesAgainst: 0,
            executed: false,
            expiration: block.timestamp + 7 days,
            category: category,
            descriptionHash: descriptionHash
        });
        emit ProposalCreated(proposalCount, msg.sender);
        return proposalCount;
    }

    /// @notice Casts a vote on a proposal.
    /// @param proposalId ID of the proposal.
    /// @param support True for yes, false for no.
    function voteOnProposal(uint256 proposalId, bool support) public {
        if (votingPower[msg.sender] == 0) revert NoVotingPower(msg.sender);

        Proposal storage proposal = proposals[proposalId];
        if (proposal.proposer == address(0)) revert ProposalNotExists(proposalId);
        if (proposal.executed) revert AlreadyExecuted(proposalId);
        if (block.timestamp > proposal.expiration) revert ProposalExpired(block.timestamp, proposal.expiration);
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted();

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            proposal.votesFor += votingPower[msg.sender];
        } else {
            proposal.votesAgainst += votingPower[msg.sender];
        }

        emit VoteCast(msg.sender, proposalId, support);
    }

    /// @notice Executes a proposal manually. Only ADMIN_ROLE can call.
    /// @param proposalId ID to execute.
    function executeProposal(uint256 proposalId) public onlyAdmin {
        _execute(proposalId);
    }

    /// @notice Executes all eligible passed proposals automatically.
    function autoExecuteProposals() public {
        for (uint256 i = 1; i <= proposalCount; i++) {
            if (
                !proposals[i].executed && block.timestamp > proposals[i].expiration
                    && proposals[i].votesFor > proposals[i].votesAgainst
            ) {
                try this._safeExecute(i) {}
                catch Error(string memory reason) {
                    emit ProposalAutoExecutionFailed(i, reason);
                } catch (bytes memory lowLevelData) {
                    bytes4 selector;
                    assembly {
                        selector := mload(add(lowLevelData, 32))
                    }
                    if (selector == ProposalAutoExecutionFailedForUpgradeProposal.selector) {
                        emit ProposalAutoExecutionFailed(i, "Upgrade proposal must be executed by admin");
                        emit UpgradeExecutionBlocked(i);
                    } else {
                        emit ProposalAutoExecutionFailed(i, _getRevertMsg(lowLevelData));
                    }
                }
            }
        }
    }

    /// @dev Calls _execute via internal self-call.
    /// @param proposalId Proposal to execute.
    function _safeExecute(uint256 proposalId) external {
        if (msg.sender != address(this)) revert OnlySelfCallAllowed();
        _execute(proposalId);
    }

    /// @dev Internal function to execute a proposal.
    function _execute(uint256 proposalId) internal {
        Proposal storage p = proposals[proposalId];
        if (p.proposer == address(0)) revert ProposalNotExists(proposalId);
        if (p.executed) revert AlreadyExecuted(proposalId);
        if (p.votesFor <= p.votesAgainst) revert ProposalDidNotPass(p.votesFor, p.votesAgainst);

        uint256 totalVotes = p.votesFor + p.votesAgainst;
        uint256 requiredVotes = (totalSupply() * getQuorumPercentage(p.category)) / 100;
        if (totalVotes < requiredVotes) revert NotEnoughVotes(totalVotes, requiredVotes);

        if (queuedAt[proposalId] == 0) {
            if (block.timestamp > p.expiration + EXECUTION_DELAY) revert ProposalDidNotPass(p.votesFor, p.votesAgainst);
            queuedAt[proposalId] = block.timestamp;
            return;
        }

        if (block.timestamp < queuedAt[proposalId] + EXECUTION_DELAY) {
            revert TimelockNotExpired(block.timestamp, queuedAt[proposalId] + EXECUTION_DELAY);
        }

        if (p.category == Category.Upgrade && !hasRole(ADMIN_ROLE, msg.sender)) {
            revert ProposalAutoExecutionFailedForUpgradeProposal(proposalId);
        }

        p.executed = true;
        (bool success,) = p.target.call{value: p.value}(p.data);
        if (!success) revert ExecutionFailed();
        emit ProposalExecuted(proposalId);
    }

    /// @notice Cancels a proposal before execution.
    /// @param proposalId ID of the proposal.
    function cancelProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        if (p.executed) revert AlreadyExecuted(proposalId);
        if (msg.sender != p.proposer && !hasRole(ADMIN_ROLE, msg.sender)) {
            revert NotAuthorizedToCancelThisProposal(msg.sender);
        }
        p.executed = true; // Mark as executed to block future execution
        emit ProposalCancelled(proposalId);
    }

    // ========== Admin Utilities ==========

    /// @notice Grants ADMIN_ROLE to another account.
    function grantAdminRole(address account) public onlyRole(ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
    }

    /// @notice Revokes ADMIN_ROLE from an account.
    function revokeAdminRole(address account) public onlyRole(ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
    }

    /// @notice Transfers ADMIN_ROLE to a new account.
    function transferAdminRole(address newAdmin) public onlyRole(ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, msg.sender);
        grantRole(ADMIN_ROLE, newAdmin);
    }

    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert NotAdmin();
        _;
    }

    // ========== View Utilities ==========

    /// @notice Returns the quorum percentage required for a proposal category.
    function getQuorumPercentage(Category category) public pure returns (uint256) {
        if (category == Category.Upgrade) return 20;
        if (category == Category.Treasury) return 10;
        return 5;
    }

    /// @notice Returns the current voting power of an account.
    function getVotes(address account) public view returns (uint256) {
        return votingPower[account];
    }

    /// @notice Returns a proposal by ID.
    function getProposal(uint256 proposalId) public view returns (Proposal memory) {
        return proposals[proposalId];
    }

    /// @notice Returns all proposals created.
    function getProposals() public view returns (Proposal[] memory) {
        Proposal[] memory list = new Proposal[](proposalCount);
        for (uint256 i = 1; i <= proposalCount; i++) {
            list[i - 1] = proposals[i];
        }
        return list;
    }

    /// @dev Extracts a string revert message from returned call data.
    function _getRevertMsg(bytes memory data) internal pure returns (string memory) {
        if (data.length < 68) return "Execution reverted (no reason)";
        assembly {
            data := add(data, 0x04)
        }
        return abi.decode(data, (string));
    }

    /// @dev Temporary helper to set timelock timestamp (for testing only).
    function setQueuedAt(uint256 proposalId, uint256 timestamp) external {
        queuedAt[proposalId] = timestamp;
    }

    // ========== Fallback ==========
    receive() external payable {}
}
