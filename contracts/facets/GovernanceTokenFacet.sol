// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondStorage} from "../DiamondStorage.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {LibErrors} from "../libraries/LibErrors.sol";
import {IGovernanceTokenFacet} from "../interfaces/IGovernanceTokenFacet.sol";
import {ERC20} from "./ERC20Facet.sol";

/**
 * @title GovernanceTokenFacet
 * @notice Facet exposing GovernanceToken logic for Diamond. All logic is implemented here or delegated to a library.
 * @dev Uses DiamondStorage for upgrade-safe storage. Handles voting, proposals, vesting, and role management.
 */
contract GovernanceTokenFacet is IGovernanceTokenFacet {
    using DiamondStorage for DiamondStorage.Layout;
    using AccessControlLib for *;

    // ========== Constants ==========
    uint256 public constant EXECUTION_DELAY = 1 days;
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    // ========== Role Definitions ==========
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");
    bytes32 public constant VESTER_ROLE = keccak256("VESTER_ROLE");
    
    // ========== Events ==========
    event DelegateChanged(address indexed delegator, address indexed to);
    event TokensLocked(address indexed holder, uint256 unlockTime);
    event ProposalCreated(uint256 indexed proposalId, address proposer);
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalAutoExecutionFailed(uint256 indexed proposalId, string reason);
    event ProposalCancelled(uint256 indexed proposalId);
    event UpgradeExecutionBlocked(uint256 proposalId);
    event VestingGranted(address indexed beneficiary, uint256 amount, uint256 start, uint256 cliff, uint256 duration, bool revocable);
    event VestingRevoked(address indexed beneficiary);
    event VestedTokensReleased(address indexed beneficiary, uint256 amount);

    function getDS() internal pure returns (DiamondStorage.Layout storage ds) {
       return DiamondStorage.layout();
    }

    // ========== Access Control ==========

    modifier onlyRole(bytes32 role) {
        AccessControlLib.checkRole(role, msg.sender);
       _;
    }

    function grantRole(bytes32 role, address account) external onlyRole(ADMIN_ROLE) {
        getDS().roles[role][account] = true;
    }

    /// @notice Grants ADMIN_ROLE to another account.
    function grantAdminRole(address account) external {
        AccessControlLib.grantRole(DiamondStorage.ADMIN_ROLE, account, msg.sender);
    }

    /// @notice Revokes ADMIN_ROLE from an account.
    function revokeAdminRole(address account) external {
        AccessControlLib.revokeRole(DiamondStorage.ADMIN_ROLE, account, msg.sender);
    }
    
    /// @notice Transfers ADMIN_ROLE to a new account.
    function transferAdminRole(address newAdmin) public onlyRole(ADMIN_ROLE) {
        AccessControlLib.revokeRole(DiamondStorage.ADMIN_ROLE, msg.sender, msg.sender);
        AccessControlLib.grantRole(DiamondStorage.ADMIN_ROLE, newAdmin, msg.sender);
    }

    function hasRole(bytes32 role, address account) internal view returns (bool) {
       return AccessControlLib._hasRole(role,account);
    }

    // ========== ReentrancyGuard ==========

    modifier nonReentrant() {
        require(!getDS()._entered, "ReentrancyGuard: reentrant call");
        getDS()._entered = true;
        _;
        getDS()._entered = false;
    }

    /// @dev Add ERC20 and AccessControl functionality Later
    function initialize(address deployer) external {
        // Prevent re-initialization
        if (getDS().totalSupply > 0) revert AlreadyInitialized();

        getDS().name = "GovernanceTokenForDAIP";
        getDS().symbol = "GT-5";

        // Mint initial supply
        getDS().balances[deployer] = INITIAL_SUPPLY;
        getDS().totalSupply = INITIAL_SUPPLY;

        // Grant all roles to deployer
        getDS().roles[keccak256("DEFAULT_ADMIN_ROLE")][deployer] = true;
        getDS().roles[keccak256("ADMIN_ROLE")][deployer] = true;
        getDS().roles[keccak256("MINTER_ROLE")][deployer] = true;
        getDS().roles[keccak256("LOCKER_ROLE")][deployer] = true;
        getDS().roles[keccak256("VESTER_ROLE")][deployer] = true;
    
        // Set delegation
        getDS().delegates[deployer] = deployer;
        getDS().votingPower[deployer] = INITIAL_SUPPLY;

        emit Transfer(address(0), deployer, INITIAL_SUPPLY);
    }

    // ========== Token Mechanics ==========

    /// @notice Mints new tokens to an address.
    /// @param to Recipient address.
    /// @param amount Amount of tokens to mint.
    function mintTokens(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        ERC20Facet.mint(to, amount);
        address delegatee = getDS().delegates[to] == address(0) ? to : getDS().delegates[to];
        _moveVotingPower(address(0), delegatee, amount);
    }

    /// @notice Transfers tokens and updates voting power.
    /// @dev Enforces token lockup.
    function transfer(address to, uint256 amount) public override nonReentrant returns (bool) {
        if (getDS().lockupEnd[msg.sender] > block.timestamp) {
            revert LibErrors.TokensLockedError(getDS().lockupEnd[msg.sender]);
        }
        uint256 senderBalance = ERC20Facet.balanceOf(msg.sender);
        if (senderBalance < amount) revert LibErrors.InsufficientBalance(senderBalance, amount);
        ERC20Facet.transfer(msg.sender, to, amount);
        _afterTokenTransfer(msg.sender, to, amount);
        return true;
    }

    /// @dev Hook that updates delegated voting power after token transfers.
    /// @param from The address tokens are transferred from.
    /// @param to The address tokens are transferred to.
    /// @param amount The amount of tokens transferred.
    function _afterTokenTransfer(address from, address to, uint256 amount) internal {
        address fromDelegate = getDS().delegates[from] == address(0) ? from : getDS().delegates[from];
        address toDelegate = getDS().delegates[to] == address(0) ? to : getDS().delegates[to];
        _moveVotingPower(fromDelegate, toDelegate, amount);
    }

    /// @dev Internal function to adjust voting power between delegates.
    /// @param from The address losing voting power.
    /// @param to The address gaining voting power.
    /// @param amount The number of tokens to adjust.
    function _moveVotingPower(address from, address to, uint256 amount) internal {
        if (amount > 0) {
            if (from != address(0)) getDS().votingPower[from] -= amount;
            if (to != address(0)) getDS().votingPower[to] += amount;
        }
    }

    /// @notice Delegates voting power to another address.
    /// @param to Address to delegate to.
    function delegateVotingPower(address to) public {
        address previous = getDS().delegates[msg.sender];
        uint256 balance = ERC20Facet.balanceOf(msg.sender);
        _moveVotingPower(previous == address(0) ? msg.sender : previous, to, balance);
        getDS().delegates[msg.sender] = to;
        emit DelegateChanged(msg.sender, to);
    }

    /// @notice Locks tokens for a user for a specified duration.
    /// @param user The address to lock tokens for.
    /// @param duration Lock duration in seconds.
    function lockTokens(address user, uint256 duration) public onlyRole(LOCKER_ROLE) {
        uint256 unlockTime = block.timestamp + duration;
        getDS().lockupEnd[user] = unlockTime;
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
        if (getDS().vestings[beneficiary].amount != 0 && !getDS().vestings[beneficiary].revoked) {
            revert AlreadyVesting(beneficiary);
        }

        getDS().vestings[beneficiary] = DiamondStorage.VestingSchedule({
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
            getDS().lockupEnd[beneficiary] = unlockTime;
            emit TokensLocked(beneficiary, unlockTime);
        }

        emit VestingGranted(beneficiary, amount, start, cliff, duration, revocable);
    }

    /// @notice Releases vested tokens to the caller.
    function releaseVestedTokens() public nonReentrant {
        VestingSchedule storage vesting = getDS().vestings[msg.sender];
        if (vesting.amount == 0) revert NoVestingSchedule();
        if (vesting.revoked) revert Error__VestingRevoked();

        uint256 vested = _vestedAmount(vesting);
        uint256 unreleased = vested - vesting.released;
        if (unreleased == 0) revert NoTokensToRelease();

        vesting.released += unreleased;
        ERC20Facet.mint(msg.sender, unreleased);

        address delegatee = getDS().delegates[msg.sender] == address(0) ? msg.sender : getDS().delegates[msg.sender];
        getDS().votingPower[delegatee] += unreleased;

        emit VestedTokensReleased(msg.sender, unreleased);
    }

    /// @notice Revokes a vesting schedule.
    /// @param beneficiary The beneficiary to revoke.
    function revokeVesting(address beneficiary) public onlyRole(VESTER_ROLE) {
        VestingSchedule storage vesting = getDS().vestings[beneficiary];
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

    // ========== Governance ===========

    /// @notice Creates a new proposal.
    /// @param target Address to call.
    /// @param value ETH to send.
    /// @param data Call data.
    /// @param category Proposal category (uint8 for interface compatibility).
    /// @param descriptionHash IPFS hash of description.
    function createProposal(
        address target,
        uint256 value,
        bytes memory data,
        uint8 category,
        string memory descriptionHash
    ) public override returns (uint256) {
        DiamondStorage.Category cat = DiamondStorage.Category(category);
        getDS().proposalCount++;
        getDS().proposals[getDS().proposalCount] = DiamondStorage.Proposal({
            proposer: msg.sender,
            target: target,
            value: value,
            data: data,
            votesFor: 0,
            votesAgainst: 0,
            executed: false,
            expiration: block.timestamp + 7 days,
            category: cat,
            descriptionHash: descriptionHash
        });
        emit ProposalCreated(getDS().proposalCount, msg.sender);
        return getDS().proposalCount;
    }

    /// @notice Casts a vote on a proposal.
    /// @param proposalId ID of the proposal.
    /// @param support True for yes, false for no.
    function voteOnProposal(uint256 proposalId, bool support) public {
        if (getDS().votingPower[msg.sender] == 0) revert NoVotingPower(msg.sender);
        DiamondStorage.Proposal storage proposal = getDS().proposals[proposalId];
        if (proposal.proposer == address(0)) revert ProposalNotExists(proposalId);
        if (proposal.executed) revert AlreadyExecuted(proposalId);
        if (block.timestamp > proposal.expiration) revert ProposalExpired(block.timestamp, proposal.expiration);
        if (getDS().hasVoted[proposalId][msg.sender]) revert AlreadyVoted();

        getDS().hasVoted[proposalId][msg.sender] = true;

        if (support) {
            proposal.votesFor += getDS().votingPower[msg.sender];
        } else {
            proposal.votesAgainst += getDS().votingPower[msg.sender];
        }

        emit VoteCast(msg.sender, proposalId, support);
    }

    /// @notice Executes a proposal manually. Only ADMIN_ROLE can call.
    /// @param proposalId ID to execute.
    function executeProposal(uint256 proposalId) public onlyRole(ADMIN_ROLE) {
        _execute(proposalId);
    }

    /// @notice Executes all eligible passed proposals automatically.
    function autoExecuteProposals() public {
        for (uint256 i = 1; i <= getDS().proposalCount; i++) {
            if (
                !DiamondStorage.proposals[i].executed &&
                block.timestamp > proposals[i].expiration &&
                proposals[i].votesFor > proposals[i].votesAgainst
            ) {
                try this._safeExecute(i) {} catch Error(string memory reason) {
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

        (bool success, ) = p.target.call{value: p.value}(p.data);
        if (!success) revert ExecutionFailed();
        p.executed = true;
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
   
    // ========== View Utilities ==========

    /// @notice Returns the quorum percentage required for a proposal category.
    function getQuorumPercentage(uint8 category) public pure override returns (uint256) {
        DiamondStorage.Category cat = DiamondStorage.Category(category);
        if (cat == DiamondStorage.Category.Upgrade) return 20;
        if (cat == DiamondStorage.Category.Treasury) return 10;
        return 5;
    }

    /// @notice Returns the current voting power of an account.
    function getVotes(address account) public view returns (uint256) {
        return votingPower[account];
    }

    /// @notice Returns a proposal by ID.
    function getProposal(uint256 proposalId) public view override returns (Proposal memory) {
        
        DiamondStorage.Proposal storage p = getDS().proposals[proposalId];
        return Proposal({
            proposer: p.proposer,
            target: p.target,
            value: p.value,
            data: p.data,
            votesFor: p.votesFor,
            votesAgainst: p.votesAgainst,
            executed: p.executed,
            expiration: p.expiration,
            category: uint8(p.category),
            descriptionHash: p.descriptionHash
        });
    }

    /// @notice Returns all proposals created.
    function getProposals() public view override returns (Proposal[] memory) {
        
        Proposal[] memory list = new Proposal[](getDS().proposalCount);
        for (uint256 i = 1; i <= getDS().proposalCount; i++) {
            DiamondStorage.Proposal storage p = getDS().proposals[i];
            list[i - 1] = Proposal({
                proposer: p.proposer,
                target: p.target,
                value: p.value,
                data: p.data,
                votesFor: p.votesFor,
                votesAgainst: p.votesAgainst,
                executed: p.executed,
                expiration: p.expiration,
                category: uint8(p.category),
                descriptionHash: p.descriptionHash
            });
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
}
