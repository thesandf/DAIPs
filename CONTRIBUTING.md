
#  Contributing to DAIP

Welcome! 🎉 Thank you for taking the time to contribute to **DAIP** – a decentralized platform for governing, minting, and trading intellectual property NFTs with on-chain proposals, role-based access, vesting, and royalty management.

We’re building in the open, and we’d love your help in improving DAIP's smart contracts, frontend, docs, and research. ✨

---

## 📚 Table of Contents

- [Getting Started](#getting-started)
- [Ways to Contribute](#ways-to-contribute)
- [Code Guidelines](#code-guidelines)
- [Pull Request Process](#pull-request-process)
- [Smart Contract Best Practices](#smart-contract-best-practices)
- [Code of Conduct](#code-of-conduct)

---

## 🛠 Getting Started

1. **Fork** this repo and clone it locally:
   ```bash
   git clone https://github.com/thesandf/DAIPs.git
   cd daip
   ```

2. **Install dependencies**:
   ```bash
   npm install
   ```

3. **Start the local environment** (if frontend):
   ```bash
   npm run dev
   ```

4. **Compile contracts** (if working with Solidity):
   ```bash
   npx hardhat compile
   ```

---

## 🚀 Ways to Contribute

You can contribute in many ways:

- 🐞 Report bugs or security issues
- 🧠 Propose ideas or governance models
- 🛡️ Improve smart contract logic
- 💅 Refactor or style frontend components
- 📖 Add or fix documentation
- 🌍 Translate interface or docs

---

## 🧾 Code Guidelines

- Use **descriptive commit messages**.
- Follow existing **code style and formatting** (Solidity, TypeScript, Markdown).
- Add **NatSpec comments** to Solidity functions.
- Always include **tests** for new functionality.
- Use `git rebase` to keep a clean history.

---

## ✅ Pull Request Process

1. Fork and create your branch:
   ```bash
   git checkout -b feat/your-feature-name
   ```

2. Commit your changes:
   ```bash
   git commit -m "feat: added proposal category filtering"
   ```

3. Push and create a pull request:
   ```bash
   git push origin feat/your-feature-name
   ```

4. Ensure:
   - CI passes ✅
   - PR has context, description, and screenshots (if frontend)
   - Label it appropriately (`feature`, `fix`, `docs`, etc.)

---

## 🔐 Smart Contract Best Practices

- Use latest OpenZeppelin contracts.
- Ensure **no unbounded loops** or **gas griefing risks**.
- Use **`onlyRole`/`onlyOwner`** modifiers where applicable.
- Validate all external inputs (`require`, `revert`, `custom errors`).
- Use **SafeMath** where needed (although Solidity ≥0.8 handles it).
- Keep contracts **modular** and **upgradeable-ready** (if planned).

---

## 🤝 Code of Conduct

We follow a [Code of Conduct](https://opensource.guide/code-of-conduct/) to ensure a safe, respectful, and productive community.

Please be kind, inclusive, and constructive in all your interactions.

---

## 💬 Questions?

Open an issue, or reach out via [Discussions](https://github.com/thesandf/DAIPs/discussions) if you’re unsure where to begin.

---

Thank you for contributing to the future of decentralized intellectual property! 🧬🚀

