## ⚠️ Disclaimer

This project is created for **educational purposes only** and is not intended for use in production environments. 

# 🛠️ Decentralized Autonomous Intellectual Property (DAIP) Platform .

### The Decentralized Autonomous Intellectual Property (DAIP) Platform is a decentralized application (dApp) that allows users to create, manage, buy, sell, and govern digital assets representing intellectual properties. These DAIPs combine the features of NFTs (Non-Fungible Tokens) and DAOs (Decentralized Autonomous Organizations), providing a new model for managing intellectual property with community-driven governance.

### This project integrates smart contracts on Ethereum (or other EVM-compatible networks), NFT standards, and DAO governance mechanisms to bring full decentralization and transparency to intellectual property rights management.

## Features

### 🌟 Core Features
- **Create DAIPs**: Mint unique DAIP tokens that represent intellectual property such as books, music, software licenses, etc., via governance-controlled minting.
- **Trade DAIPs**: A decentralized marketplace enables users to list, buy, sell, and bid on DAIPs using ERC20 tokens such as USDC.
- **DAO Governance**: The GovernanceToken smart contract supports delegation, voting, proposal creation, execution delays, and category-based permission controls.
- **Royalty Enforcement**: Built-in royalty and platform fee logic ensures fair payouts to original DAIP creators.
- **Escrow-based Bidding**: Timed auctions with bid expiration, refunds, and minimum increment enforcement.
- **Metadata Control**: Supports upgradable metadata with optional freezing under governance authority.
- **Smart Contracts**: All logic is secured by Ethereum smart contracts.

## 🔧 Planned Enhancements
- **DeFi Integration**: Earn royalties or lending income from DAIPs through decentralized finance protocols.
- **Cross-Market Compatibility**: Trade DAIPs on platforms like OpenSea.
- **AI Auditing**: Automatic IP auditing and compliance via AI.
- **Fee Optimization**: Gas-optimized operations and efficient batch transactions.

## Tech Stack

### Backend (Smart Contracts)
- **Solidity**: Language for writing smart contracts.
- **Foundry**: Toolkit for smart contract development and testing.
- **OpenZeppelin Contracts**: Security-audited libraries for ERC standards and access control.

### Frontend (dApp)
- **Next.js**: React-based framework for building user interfaces.
- **Ethers.js**: Ethereum interaction library.
- **Tailwind CSS**: Utility-first framework for responsive UIs.

### Blockchain & Tools
- **Ethereum (Goerli/Mumbai)**: Main and test networks.
- **MetaMask**: Wallet for account and transaction management.
- **Infura**: Ethereum infrastructure service for node access.

## Architecture Overview


### 🧩 Smart Contracts
- **GovernanceToken.sol**: Implements ERC20 with delegation, voting power, locking, vesting, and proposal mechanics.
- **DAIPMarketplace.sol**: Custom ERC721 with listing, bidding, royalties, transfer restrictions, metadata control, and governance integration.
- **Escrow Auctions**: Time-based bid escrow and refund mechanisms.

### 🖥️ Application Layers
- **Token Layer**: ERC-721 DAIP NFTs.
- **Governance Layer**: Proposal-based management with Upgrade/Treasury/General categories.
- **Marketplace Layer**: Secure asset trade, royalty handling, bidding, and platform fee management.
- **Frontend**: User interface for all operations (mint, vote, trade, propose).

---

## 📖 Recommended Reading for DAIP Project

| Section                    | Suggested Resources |
|---------------------------|----------------------|
| **Concept & Motivation**  | [NFTs as Decentralized Intellectual Property – Edward Lee](https://illinoislawreview.org/wp-content/uploads/2023/08/Lee.pdf?utm_source=thesandf.xyz) , [Building a Decentralized, AI-Powered IP Registry – Lynksite](https://www.linkedin.com/pulse/building-decentralized-ai-powered-intellectual-property-registry-pxruf?utm_source=thesandf.xyz)  |
| **Architecture & Workflow** | [Building a Decentralized, AI-Powered IP Registry – Lynksite](https://www.linkedin.com/pulse/building-decentralized-ai-powered-intellectual-property-registry-pxruf?utm_source=thesandf.xyz) , [Tokenized Ideas: Intellectual Property Meets Blockchain – Sologenic/Medium](https://sologenic.medium.com/tokenized-ideas-intellectual-property-meets-blockchain-c964b6feb739?utm_source=thesandf.xyz)  |
| **Market & Trends**        | [Tokenized Ideas: Intellectual Property Meets Blockchain – Sologenic/Medium](https://sologenic.medium.com/tokenized-ideas-intellectual-property-meets-blockchain-c964b6feb739?utm_source=thesandf.xyz) , [How Blockchain is Reshaping IP Licensing – OneSafe Blog](https://www.onesafe.io/blog/blockchain-impact-on-ip-licensing?utm_source=thesandf.xyz) |
| **Legal & Compliance**     | [NFTs as Decentralized Intellectual Property – Edward Lee](https://illinoislawreview.org/wp-content/uploads/2023/08/Lee.pdf?utm_source=thesandf.xyz) , [Blockchain & IP Law Essentials – Number Analytics (OneSafe)](https://www.numberanalytics.com/blog/blockchain-ip-law-essentials?utm_source=thesandf.xyz) |


## Getting Started

### Prerequisites
- Node.js
- MetaMask
- Foundry
- Ethereum testnet account

### Installation
```sh
git clone https://github.com/thesandf/DAIPs
cd DAIPs
npm install
```

### Environment Variables
```sh
NEXT_PUBLIC_INFURA_PROJECT_ID=<your-infura-project-id>
NEXT_PUBLIC_CONTRACT_ADDRESS=<deployed-daip-contract-address>
```

### Deployment
```sh
forge create --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> src/DAIP.sol
```

### Run dApp
```sh
npm run dev
```

Open in browser: `http://localhost:3000`

## Smart Contract Overview

### 🧾 GovernanceToken.sol
- Role-based access for minting, vesting, admin controls
- Delegate-based voting system
- Time-locked proposal execution
- Category-based permission gating (Upgrade, Treasury, General)
- On-chain metadata support (IPFS hash)

### 🛒 DAIPMarketplace.sol
- Governance-controlled minting of DAIP NFTs
- Listing and delisting of NFTs
- USDC-based marketplace with royalty and platform fees
- Time-limited bids with escrow and refund
- Metadata control and freezing
- Transfer restrictions and statistics
- DAO-based parameter updates

---

## 🤝 Open for Contributions

This repository is open to contributors! If you'd like to suggest improvements, add new features, or help optimize gas usage or architecture, you're welcome to submit PRs.

📄 Please refer to the **[CONTRIBUTING.md](./CONTRIBUTING.md)** file in the root directory for guidelines on how to contribute effectively.

---

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements
- [OpenZeppelin](https://www.openzeppelin.com/) for secure smart contract libraries.
- [Ethers.js](https://docs.ethers.org/v6/) for Ethereum integration.
- [MetaMask](https://metamask.io/) for wallet support.

---
