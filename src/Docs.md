
## 🧾 Overview

The **DAIP Platform** is a decentralized intellectual property marketplace and governance ecosystem powered by Ethereum smart contracts. It includes two main components:

1. **DAIPMarketplace.sol** – A custom ERC-721-based marketplace for trading intellectual property NFTs with governance-controlled minting, royalties, bidding, and metadata management.
2. **GovernanceToken.sol** – An ERC-20 governance token that supports delegated voting, time-locked proposals, role-based permissions, and DAO-controlled operations.

This repository aims to provide a modular, secure, and fully decentralized platform for managing and monetizing IP using NFTs and DAOs.

---

## 📦 Contract Highlights

### DAIPMarketplace.sol

* Governance-only minting of DAIP NFTs
* USDC-based marketplace with royalties and platform fees
* Bidding with expiration, minimum increments, and escrowed funds
* Transfer restrictions, metadata freezing, and royalty updates
* Built-in admin controls for fee updates and governance role enforcement

### GovernanceToken.sol

* ERC-20 token with delegation and dynamic voting power
* Role-based permissions for minting, vesting, and locking
* Proposal lifecycle with timelock and category-based execution control (General, Treasury, Upgrade)
* IPFS-linked metadata support for proposals

---

## ✨ Coming Soon: Diamond Proxy Support

The project will soon support the **EIP-2535 Diamond Standard** for modular, upgradeable contracts with facets. Stay tuned for a more scalable and gas-efficient architecture.

---

## 🤝 Open for Contributions

This repository is open to contributors! If you'd like to suggest improvements, add new features, or help optimize gas usage or architecture, you're welcome to submit PRs.

📄 Please refer to the **[CONTRIBUTING.md](../CONTRIBUTING.md)** file in the root directory for guidelines on how to contribute effectively.

---


# DAIPMarketplace.sol Documentation [🔝 Go to Top](#top)



## Overview

The **DAIPMarketplace** smart contract is a decentralized intellectual property trading platform built on the ERC-721 standard. It enables governance-controlled minting, auctioning, bidding, and transfer of digital IP NFTs using a stable ERC-20 token (e.g., USDC).

The contract supports governance-based metadata management, creator royalties, platform fees, and bid management with expiry and refund mechanisms.

---

## Key Components

### ERC-721 Integration

* Inherits from `ERC721URIStorage` to allow metadata URI customization.
* Each DAIP NFT is uniquely identifiable and tradeable.

### Governance Integration

* Only addresses with `ADMIN_ROLE` from the `GovernanceToken` contract can mint new DAIP NFTs.
* Admins can freeze or update metadata and royalties.

### Payments

* Uses an ERC-20 token (e.g., USDC) for purchases and bids.
* Platform fee and royalties are deducted automatically from every transaction.

---

## Features

### 1. **Minting**

Only governance admins can mint DAIPs.

```solidity
function mintDAIP(string memory _tokenURI, uint256 _royaltyPercentage)
```

* Enforces a royalty cap of 10%.
* Stores creator, royalty data, and initializes listing.

### 2. **Listing & Buying**

```solidity
function listDAIP(uint256 _daipId, uint256 _price)
function buyDAIP(uint256 _daipId)
```

* Users can list NFTs they own.
* Buyers pay in USDC. Royalties and platform fees are distributed.

### 3. **Bidding System**

```solidity
function placeBid(uint256 _daipId, uint256 _amount, uint256 _expiration)
function acceptBid(uint256 _daipId)
function withdrawExpiredBid(uint256 _daipId)
```

* Bids must increase by at least 5%.
* Funds are escrowed.
* Sellers can accept the bid, or bidders can withdraw expired bids.

### 4. **Governance Admin Functions**

```solidity
function updateTokenURI(uint256 _daipId, string memory _newURI)
function freezeMetadata(uint256 _daipId)
function updateRoyalty(uint256 _daipId, uint256 _newRoyalty)
```

* Admins can modify metadata or royalty (unless frozen).

### 5. **Access & Transfer Control**

```solidity
function proposeTransferRestriction(uint256 _daipId, bool restrictTransfer)
```

* NFT owners can restrict future transfers of their tokens.

### 6. **Platform Management**

```solidity
function updatePlatformFee(uint256 _newFee)
```

* Owner can update fee (max 10%).

---

## Events

* `DAIPMinted`, `DAIPListed`, `DAIPSold`, `DAIPDelisted`
* `BidPlaced`, `BidAccepted`, `BidRefunded`
* `PlatformFeeUpdated`, `RoyaltyUpdated`
* `MetadataUpdated`, `MetadataFrozen`

---

## Utility Functions

```solidity
function getDAIPListing(uint256 _daipId)
function getDAIPBid(uint256 _daipId)
function getUserStats(address user)
```

---

## Security Considerations

* Uses `ReentrancyGuard` to prevent reentrancy in payments.
* Uses strict access control for minting, royalty updates, and metadata changes.

---

## Future Enhancements

* Escrow-backed dispute resolution
* Auction support with time extensions
* Cross-chain/multi-token listing support
* DAO-triggered marketplace actions via `GovernanceToken`

---

## Contract Dependencies

* [OpenZeppelin ERC721URIStorage](https://docs.openzeppelin.com/contracts/4.x/api/token/erc721#ERC721URIStorage)
* [IERC20](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#IERC20)
* [Ownable](https://docs.openzeppelin.com/contracts/4.x/api/access#Ownable)
* `GovernanceToken` interface for `hasRole()` access control

---


❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️❇️


---


# GovernanceToken.sol - Documentation[🔝 Go to Top](#top) 



## Overview
The `GovernanceToken` contract is an ERC-20 based governance token designed to power decentralized governance for the DAIP ecosystem. It integrates role-based access control, delegated voting power, token vesting, and a proposal/voting system with execution delays and category restrictions.

---

## Key Features

### ✅ ERC-20 Governance Token
- Standard ERC-20 interface with burn and transfer overrides.
- Role-based minting and locking mechanisms.

### ✅ Voting & Delegation
- Delegated voting power similar to Compound's model.
- `votingPower` mapping tracks effective voting rights of delegates.
- Voting power updates automatically on transfer, mint, vest, or delegation.

### ✅ Role-Based Permissions
- `ADMIN_ROLE`: Can manage proposals and other roles.
- `MINTER_ROLE`: Can mint new governance tokens.
- `LOCKER_ROLE`: Can lock tokens from being transferred.
- `VESTER_ROLE`: Can assign vesting schedules.

### ✅ Token Locking & Vesting
- Tokens can be locked with a timestamp (`lockTokens`).
- Vested tokens can be released after being granted by a vester (`releaseVestedTokens`).

---

## Governance System

### 🧾 Proposal Categories
- Enum: `Category { General, Treasury, Upgrade }`
- Upgrade proposals require admin-level execution.

### 🗳️ Proposal Lifecycle
- Any token holder can create a proposal.
- Votes are cast using delegated voting power.
- Voting lasts 7 days.
- Proposal needs more FOR votes than AGAINST.
- Once passed, it’s queued and must wait 1 day (timelock).

### 🛡️ Execution Security
- `Upgrade` proposals can only be executed by admins.
- Delay enforced using `queuedAt[proposalId]` + `EXECUTION_DELAY`.

### 🧾 On-Chain Metadata
- Proposals include `descriptionHash` (IPFS hash or rich metadata reference).

---

## Contract Components

### ✅ Constructor
Initializes total supply, assigns all roles to the deployer, and sets self-delegation.

### ✅ Delegation Logic
```solidity
function delegateVotingPower(address to) external
```
- Transfers voting rights to another address.
- Updates `votingPower` mappings.

### ✅ Proposal Structure
```solidity
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
```

### ✅ Proposal Functions
```solidity
function createProposal(...)
function voteOnProposal(...)
function executeProposal(...)
function autoExecuteProposals()
```

### ✅ Utility Functions
- `getProposal(uint256)`
- `getProposals()`
- `getVotes(address)`

---

## Events
- `DelegateChanged`
- `ProposalCreated`
- `VoteCast`
- `ProposalExecuted`
- `TokensLocked`
- `MetadataUpdated`

---

## Access Management
- `grantAdminRole`, `revokeAdminRole`, `transferAdminRole`

---

## Timelock & Queuing
- Proposal execution delayed using `queuedAt` mapping.
- `EXECUTION_DELAY = 1 days`

---

## Security Considerations
- Proposal execution restrictions by category.
- Locked tokens cannot be transferred.
- Only admins can create and execute Upgrade proposals.

---

## Future Upgrades (Optional)
- Snapshot-based voting.
- Gasless voting via off-chain signatures.
- DAO treasury integration.

---

## License
This contract is licensed under MIT.

---
 
## Summary    [🔝 Go to Top](#top)
The `GovernanceToken` contract provides a secure and flexible on-chain governance system for DAIP with support for roles, proposals, timelocks, and delegated voting. It integrates tightly with DAIPMarketplace via role-checking and is suitable for decentralized governance applications.











