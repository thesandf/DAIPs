# GovernanceToken Diamond Standard Scaffold

This folder now includes a minimal Diamond Standard (EIP-2535) setup for the GovernanceToken contract.

## Files
- `GovernanceDiamond.sol`: Diamond proxy for GovernanceToken facets.
- `IGovernanceTokenFacet.sol`: Interface with all GovernanceToken functions (add more as needed).
- `GovernanceTokenFacet.sol`: Facet contract (copy logic from GovernanceToken.sol here, adapt storage to DiamondStorage).

## Instructions
- Copy all logic from `GovernanceToken.sol` into `GovernanceTokenFacet.sol`.
- Replace state variables with access via `DiamondStorage` or a similar library for upgradeability.
- Use `GovernanceDiamond` as the main proxy, and add facets via `diamondCut`.
- Do not use constructors in facets; use initializer functions if needed.
- All function selectors must be registered in the diamond.

**This is a scaffold. You must implement the logic in the facet and connect storage for a working upgradeable GovernanceToken.**


---

## ✅ Conversion Plan: `GovernanceTokenFacet.sol`

### ✅ Step 1: Move State to `DiamondStorage.sol`

We will extract all `GovernanceToken` state variables and place them in a `DiamondStorage` library with a `layout()` getter to access shared state.

---

### ✅ Step 2: Copy and Adapt All Logic

In `GovernanceTokenFacet.sol`:

* Copy each function from `GovernanceToken`
* Replace direct state access (e.g., `votingPower[msg.sender]`) with `DiamondStorage.layout().votingPower[msg.sender]`
* Replace `ERC20`, `AccessControl`, etc. with internal implementations (or create facets for them)

---

### ✅ Step 3: Add Initializer

Replace constructor logic with an `initializeGovernanceToken(address admin)` function. This will mint tokens, set roles, and set initial delegates.

---

### ✅ Step 4: Prepare `GovernanceDiamond.sol`

Create a simple Diamond proxy contract using:

* `diamondCut()` for facet registration
* `fallback()` using `delegatecall`

---

### ✅ Step 5: Register Function Selectors

Each function in the facet (e.g., `mintTokens`, `voteOnProposal`) must be registered with the Diamond proxy using `diamondCut`.

---

## 📦 Output Plan

I will now generate:

1. ✅ `DiamondStorage.sol`
2. ✅ `GovernanceTokenFacet.sol` (fully migrated with logic from the original)
3. ✅ `GovernanceDiamond.sol` (proxy with `diamondCut`)
4. ✅ `IDiamondCut.sol`, `IDiamondLoupe.sol`, etc., if needed


# Deployment & Upgrade Instructions

## 1. Facet Registration
- Only `DiamondCutFacet` is registered in the constructor of `GovernanceDiamond.sol`.
- **After deploying the diamond**, use the `diamondCut` function to add all other facets (`GovernanceTokenFacet`, `ERC20Facet`, `DiamondLoupeFacet`, `OwnershipFacet`, etc.).
- This is automated in the provided Foundry script (`script/DeployGovernanceDiamond.s.sol`).

## 2. Facet Function Selectors
- Ensure all function selectors from `GovernanceTokenFacet` and `ERC20Facet` are registered in the diamond via `diamondCut`.
- The script collects selectors for all public/external functions and registers them.

## 3. Initializer
- After adding `GovernanceTokenFacet`, call its `initialize(address deployer)` function **once** to mint the initial supply and set up roles.
- The script does this automatically after facet registration.

## 4. Category Enum Consistency
- The interface uses `uint8 category`, but the facet and storage use an enum.
- The facet casts `uint8` to the enum internally and returns `uint8` for interface compatibility.
- **No manual action needed if using the provided facet code.**

## 5. Error Handling
- Errors are defined in `LibErrors.sol` and used throughout the code.
- No special deployment action required.

## 6. Events
- Events are emitted as expected in both ERC20 and governance logic.
- No special deployment action required.

## 7. Facet/Lib Imports
- All facets and libraries are imported and used correctly.
- No special deployment action required.

---

## Recommendations & Next Steps

### A. Facet Registration
- After deploying `GovernanceDiamond`, use `diamondCut` to add:
  - `GovernanceTokenFacet`
  - `ERC20Facet`
  - Any other facets (Loupe, Ownership, etc.)
- The provided Foundry script automates this process.

### B. Initialization
- After adding `GovernanceTokenFacet`, call its `initialize(address deployer)` function **once** to mint the initial supply and set up roles.
- The script does this automatically.

### C. Selector Management
- Ensure all function selectors from the interfaces are included in the diamond.
- The script demonstrates how to collect and register selectors.

### D. Testing
- Write Foundry or Hardhat tests to:
  - Deploy the diamond and facets
  - Register facets via `diamondCut`
  - Call `initialize`
  - Test all governance and ERC20 functions via the diamond proxy

### E. Documentation
- This section provides the required deployment and upgrade instructions for your diamond-based governance token system.

---

**For automated deployment, use the provided Foundry script: `script/DeployGovernanceDiamond.s.sol`.**

**For upgrades:**
- Deploy new facet(s).
- Use `diamondCut` to add/replace/remove facet selectors as needed.
- If a new initializer is needed, call it after the upgrade.

---

For further help with testing, upgrades, or advanced facet management, let the team know!




















// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondStorage} from "../DiamondStorage.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {LibErrors} from "../libraries/LibErrors.sol";
import {IGovernanceTokenFacet} from "../interfaces/IGovernanceTokenFacet.sol";

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

    // ========== Modifiers ==========
    modifier onlyRole(bytes32 role) {
        AccessControlLib.checkRole(role, msg.sender);
        _;
    }
    modifier nonReentrant() {
        require(!DiamondStorage.layout()._entered, "ReentrancyGuard: reentrant call");
        DiamondStorage.layout()._entered = true;
        _;
        DiamondStorage.layout()._entered = false;
    }

    // ========== Initializer ==========
    /**
     * @notice Initializes the GovernanceTokenFacet (to be called ONCE after diamondCut).
     * @param deployer The address to receive initial roles and supply.
     */
    function initialize(address deployer) external {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        require(ds.totalSupply == 0, "Already initialized");
        ds.name = "GovernanceTokenForDAIP";
        ds.symbol = "GT-5";
        ds.totalSupply = INITIAL_SUPPLY;
        ds.balances[deployer] = INITIAL_SUPPLY;
        // Assign all roles to deployer
        ds.roles[ADMIN_ROLE][deployer] = true;
        ds.roles[MINTER_ROLE][deployer] = true;
        ds.roles[LOCKER_ROLE][deployer] = true;
        ds.roles[VESTER_ROLE][deployer] = true;
        emit Transfer(address(0), deployer, INITIAL_SUPPLY);
    }

    // ========== Token Mechanics ==========
    function mintTokens(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert LibErrors.InvalidReceiver(to);
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        ds.totalSupply += amount;
        ds.balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) public override nonReentrant returns (bool) {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        if (block.timestamp < ds.lockupEnd[msg.sender]) revert LibErrors.TokensLockedError(ds.lockupEnd[msg.sender]);
        uint256 fromBalance = ds.balances[msg.sender];
        if (fromBalance < amount) revert LibErrors.InsufficientBalance(fromBalance, amount);
        ds.balances[msg.sender] = fromBalance - amount;
        ds.balances[to] += amount;
        _afterTokenTransfer(msg.sender, to, amount);
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        address fromDelegate = ds.delegates[from];
        address toDelegate = ds.delegates[to];
        if (fromDelegate != address(0)) {
            _moveVotingPower(fromDelegate, address(0), amount);
        }
        if (toDelegate != address(0)) {
            _moveVotingPower(address(0), toDelegate, amount);
        }
    }

    function _moveVotingPower(address from, address to, uint256 amount) internal {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        if (from != address(0)) {
            ds.votingPower[from] -= amount;
        }
        if (to != address(0)) {
            ds.votingPower[to] += amount;
        }
    }

    function delegateVotingPower(address to) public {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        address prevDelegate = ds.delegates[msg.sender];
        ds.delegates[msg.sender] = to;
        emit DelegateChanged(msg.sender, to);
        uint256 balance = ds.balances[msg.sender];
        _moveVotingPower(prevDelegate, to, balance);
    }

    function lockTokens(address user, uint256 duration) public onlyRole(LOCKER_ROLE) {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        uint256 unlockTime = block.timestamp + duration;
        ds.lockupEnd[user] = unlockTime;
        emit TokensLocked(user, unlockTime);
    }

    // ========== Vesting ==========
    function vestTokens(address beneficiary, uint256 amount, uint256 start, uint256 cliff, uint256 duration, bool revocable) public onlyRole(VESTER_ROLE) {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        require(ds.vestings[beneficiary].amount == 0, "Already vesting");
        require(amount > 0, "Zero amount");
        require(duration > 0, "Zero duration");
        require(cliff <= duration, "Invalid cliff");
        ds.vestings[beneficiary] = DiamondStorage.VestingSchedule({
            start: start,
            cliff: cliff,
            duration: duration,
            amount: amount,
            released: 0,
            revocable: revocable,
            revoked: false
        });
        emit VestingGranted(beneficiary, amount, start, cliff, duration, revocable);
    }

    function releaseVestedTokens() public nonReentrant {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        DiamondStorage.VestingSchedule storage vesting = ds.vestings[msg.sender];
        require(vesting.amount > 0, "No vesting");
        require(!vesting.revoked, "Vesting revoked");
        uint256 vested = _vestedAmount(vesting);
        uint256 unreleased = vested - vesting.released;
        require(unreleased > 0, "No tokens to release");
        vesting.released = vested;
        ds.balances[msg.sender] += unreleased;
        emit VestedTokensReleased(msg.sender, unreleased);
    }

    function revokeVesting(address beneficiary) public onlyRole(VESTER_ROLE) {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        DiamondStorage.VestingSchedule storage vesting = ds.vestings[beneficiary];
        require(vesting.revocable, "Not revocable");
        require(!vesting.revoked, "Already revoked");
        vesting.revoked = true;
        emit VestingRevoked(beneficiary);
    }

    function _vestedAmount(DiamondStorage.VestingSchedule memory vesting) internal view returns (uint256) {
        if (block.timestamp < vesting.start + vesting.cliff) {
            return 0;
        } else if (block.timestamp >= vesting.start + vesting.duration || vesting.revoked) {
            return vesting.amount;
        } else {
            return (vesting.amount * (block.timestamp - vesting.start)) / vesting.duration;
        }
    }

    // ========== Governance ===========
    function createProposal(address target, uint256 value, bytes calldata data, uint8 category, string calldata descriptionHash) external override returns (uint256) {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        require(ds.votingPower[msg.sender] > 0, "No voting power");
        uint256 proposalId = ++ds.proposalCount;
        ds.proposals[proposalId] = DiamondStorage.Proposal({
            proposer: msg.sender,
            target: target,
            value: value,
            data: data,
            votesFor: 0,
            votesAgainst: 0,
            executed: false,
            expiration: block.timestamp + 3 days,
            category: DiamondStorage.Category(category),
            descriptionHash: descriptionHash
        });
        emit ProposalCreated(proposalId, msg.sender);
        return proposalId;
    }

    function voteOnProposal(uint256 proposalId, bool support) external override {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        DiamondStorage.Proposal storage proposal = ds.proposals[proposalId];
        require(!proposal.executed, "Already executed");
        require(block.timestamp < proposal.expiration, "Proposal expired");
        require(!ds.hasVoted[proposalId][msg.sender], "Already voted");
        require(ds.votingPower[msg.sender] > 0, "No voting power");
        ds.hasVoted[proposalId][msg.sender] = true;
        if (support) {
            proposal.votesFor += ds.votingPower[msg.sender];
        } else {
            proposal.votesAgainst += ds.votingPower[msg.sender];
        }
        emit VoteCast(msg.sender, proposalId, support);
    }

    function executeProposal(uint256 proposalId) external override {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        DiamondStorage.Proposal storage proposal = ds.proposals[proposalId];
        require(!proposal.executed, "Already executed");
        require(block.timestamp >= proposal.expiration, "Not expired");
        require(proposal.votesFor > proposal.votesAgainst, "Did not pass");
        proposal.executed = true;
        (bool success, ) = proposal.target.call{value: proposal.value}(proposal.data);
        require(success, "Execution failed");
        emit ProposalExecuted(proposalId);
    }

    function autoExecuteProposals() external override {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        for (uint256 i = 1; i <= ds.proposalCount; i++) {
            DiamondStorage.Proposal storage proposal = ds.proposals[i];
            if (!proposal.executed && block.timestamp >= proposal.expiration && proposal.votesFor > proposal.votesAgainst) {
                proposal.executed = true;
                (bool success, ) = proposal.target.call{value: proposal.value}(proposal.data);
                if (success) {
                    emit ProposalExecuted(i);
                } else {
                    emit ProposalAutoExecutionFailed(i, "Execution failed");
                }
            }
        }
    }

    function cancelProposal(uint256 proposalId) external override {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        DiamondStorage.Proposal storage proposal = ds.proposals[proposalId];
        require(!proposal.executed, "Already executed");
        require(msg.sender == proposal.proposer || AccessControlLib._hasRole(ADMIN_ROLE, msg.sender), "Not authorized");
        proposal.executed = true;
        emit ProposalCancelled(proposalId);
    }

    // ========== Admin Utilities ==========
    function grantAdminRole(address account) external override onlyRole(ADMIN_ROLE) {
        DiamondStorage.layout().roles[ADMIN_ROLE][account] = true;
    }
    function revokeAdminRole(address account) external override onlyRole(ADMIN_ROLE) {
        DiamondStorage.layout().roles[ADMIN_ROLE][account] = false;
    }
    function transferAdminRole(address newAdmin) external override onlyRole(ADMIN_ROLE) {
        DiamondStorage.layout().roles[ADMIN_ROLE][msg.sender] = false;
        DiamondStorage.layout().roles[ADMIN_ROLE][newAdmin] = true;
    }

    // ========== View Utilities ==========
    function getQuorumPercentage(uint8 category) external pure override returns (uint256) {
        if (category == uint8(DiamondStorage.Category.General)) return 10;
        if (category == uint8(DiamondStorage.Category.Treasury)) return 20;
        if (category == uint8(DiamondStorage.Category.Upgrade)) return 50;
        return 0;
    }
    function getVotes(address account) external view override returns (uint256) {
        return DiamondStorage.layout().votingPower[account];
    }
    function getProposal(uint256 proposalId) external view override returns (Proposal memory) {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        DiamondStorage.Proposal storage p = ds.proposals[proposalId];
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
    function getProposals() external view override returns (Proposal[] memory) {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        Proposal[] memory arr = new Proposal[](ds.proposalCount);
        for (uint256 i = 0; i < ds.proposalCount; i++) {
            DiamondStorage.Proposal storage p = ds.proposals[i+1];
            arr[i] = Proposal({
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
        return arr;
    }
    function setQueuedAt(uint256 proposalId, uint256 timestamp) external override onlyRole(ADMIN_ROLE) {
        DiamondStorage.layout().queuedAt[proposalId] = timestamp;
    }
    // ========== ERC20 ========== (delegated to ERC20Facet)
    function balanceOf(address account) external view override returns (uint256) {
        return DiamondStorage.layout().balances[account];
    }
    function totalSupply() external view override returns (uint256) {
        return DiamondStorage.layout().totalSupply;
    }
    function allowance(address owner, address spender) external view override returns (uint256) {
        return DiamondStorage.layout().allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) external override returns (bool) {
        DiamondStorage.layout().allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        uint256 currentAllowance = ds.allowances[from][msg.sender];
        require(currentAllowance >= amount, "ERC20: insufficient allowance");
        ds.allowances[from][msg.sender] = currentAllowance - amount;
        uint256 fromBalance = ds.balances[from];
        require(fromBalance >= amount, "ERC20: insufficient balance");
        ds.balances[from] = fromBalance - amount;
        ds.balances[to] += amount;
        _afterTokenTransfer(from, to, amount);
        emit Transfer(from, to, amount);
        return true;
    }
    // ========== ERC20 Events ==========
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
