# Arenium

Welcome to **Arenium**, a modular and community-powered **decentralized prediction market protocol** built on the multiple networks. Arenium lets users create, participate in, and trade on high-stakes markets across crypto trends, sports, politics, and more — with built-in **liquidity**, **trustless resolution**, and **reward mechanisms**.

Arenium leverages:

- **UMA’s Optimistic Oracle V3** for trustless event resolution,
- **Uniswap V3 liquidity pools** for outcome token trading,
- A custom-built **AMM management contract**, and
- An upcoming **FeeHandler contract** to distribute market fees efficiently.

---

## Deployed Contracts (Mainnet Deployment)
- [TBA]

## 🔗 Deployed Contracts (Testnet Deployment)

- [PredictionMarketManager](https://base-sepolia.blockscout.com/address/0xC98735ecff2BB042632456d3a3c7251AA385bF83)
- [PredictionMarket](https://base-sepolia.blockscout.com/address/0x50baa7483bbEE0dD6859d8b150563e87A15DdCBA)
- [AMMContract](https://base-sepolia.blockscout.com/address/0x36f0074d24da94e658551e568B729f596f9F43Cb)
- FeeHandler (coming soon...)

---

## Overview

### 🧠 What Is Arenium?

Arenium is a Web3-native platform where anyone can:

1. **Create new prediction markets** with custom outcomes and parameters
2. **Mint outcome tokens** representing different market outcomes
3. **Provide liquidity** to Uniswap V3 pools for seamless trading
4. **Trade and speculate** on outcomes through our integrated AMM
5. **Assert event outcomes** through UMA's Optimistic Oracle V3
6. **Claim rewards** after trustless market resolution

All without relying on centralized oracles, custodians, or intermediaries.

---

### ✨ Key Features
### 🔮 Trustless Event Resolution

- **UMA Optimistic Oracle V3** integration ensures secure and decentralized settlement
- Supports off-chain data resolution for diverse market types
- Dispute mechanism for contentious outcomes
- Minimizes reliance on centralized oracles

2. **Automated Market Maker (AMM):**

   - Facilitates seamless trading of outcome tokens using a liquidity pool and pricing curve.
   - Implements dynamic token pricing based on supply and demand.
   - Ensures liquidity for all markets, enabling efficient trading.

3. **PredictionMarketManager Contract:**

   - Manages the lifecycle of prediction markets.
   - Facilitates market creation, event resolution w/ UMA Optimalistic Oracle V3.

4. **Fee Collection and Distribution:**

   - Transparent and configurable fee structure for market creation, trading, and settlement.
   - Supports treasury or community-driven fee allocation.
   - Fees are distributed fairly to incentivize participation and growth.

5. **Supported Tokens:**

   - Uses USDT, USDC, BTC, AVAX, and WETH as primary tokens for placing bets, providing liquidity, and earning rewards.
   - Ensures compatibility with widely-used assets for ease of use.

6. **Community-Centric Design:**

   - Features gamified elements like leaderboards, exclusive challenges, and rewards for The Arena users.
   - Encourages community participation through decentralized governance and feedback mechanisms.

7. **Built on the Avalanche Network:**
   - Leverages low transaction costs, high scalability, and robust smart contract infrastructure.
     Ensures fast and efficient market operations for a seamless user experience.

## How It Works

1. **Create or Explore Markets:** Browse existing markets or create new ones with custom outcomes.
2. **Mint Outcome Tokens:** Deposit supported tokens to mint tokens representing different outcomes.
3. **Trade on AMM:** Use the AMM to buy or sell outcome tokens based on your predictions.
4. **Participate in Settlement:** UMA’s Optimistic Oracle V3 resolves event outcomes to finalize markets.
5. **Earn Rewards:** Accurate predictions lead to token payouts, leaderboard rankings, and more.

## Repository Structure

The repository is organized for clarity and modularity:

- **`src/`**: Contains the core smart contracts:
  - `PredictionMarketManager.sol`: Manages market creation and event resolution.
  - `PredictionMarket.sol`: Manages market creation, token minting, and event resolution using UMA's Optimistic Oracle.
  - `AMMContract.sol`: Facilitates token swaps using a constant product pricing curve.
  - **`interfaces/`**: Interfaces for contracts to interact with each other:
    - `IAMMContract.sol`
    - `INonfungiblePositionManager.sol`
  - **`lib/`**: Utility and mathematical libraries:
    - `AMMStorage.sol`
    - `FullMath.sol`
    - `LiquidityAmounts.sol`
    - `PMLibrary.sol`
    - `TickMath.sol`
- **`test/`**: Unit tests to verify contract functionality and ensure security.
  - **`fork-uint/`**: Forked tests for uint256 data types.
  - **`integration/`**: Integration tests for end-to-end scenarios.
  - **`unit/`**: Unit tests for individual smart contracts.
- **`script/`**: Deployment and interaction scripts for the contracts.
  - `HelperConfig.s.sol`: Configuration for testnet and mainnet deployments.
  - **`deployments/`**: Live deployments for testnet and mainnet.
  - **`interaction-scripts/`**: Scripts for interacting with the contracts.
  - **`mocks/`**: Mock contracts for testing and simulation.
- **`docs/`**: Documentation and specifications for smart contracts.

## Getting Started

### Prerequisites

- Familiarity with Solidity and smart contract development.
- Basic understanding of Avalanche, Uniswap V3 and UMA’s Optimistic Oracle.
- Tools like Foundry or Hardhat for local development and testing.

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/AreniumApp/Arenium.git
   cd Arenium
   ```

2. Install Foundry:

   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   ```

3. Install Dependencies:

   ```bash
   forge install
   ```

4. Compile the contracts:

   ```bash
   forge build
   ```

5. Run Tests:
   ```bash
   forge test
   ```


## 📊 Roadmap

Here are some upcoming milestones for the Arenium protocol:

- ✅ Testnet deployment and full smart contract suite integration
- 🔜 Mainnet deployment on Avalanche
- 🔜 Integration with Chainlink Functions for additional data feeds
- 🔜 Frontend dApp launch with wallet connection and live markets
- 🔜 Community governance module for fee allocation and market curation
- 🔜 Bug bounty and audit completion for enhanced security

Stay tuned for frequent updates in [Discord](https://discord.gg/ThMkW8X89k).

## 🛡️ Security and Audits

Security is a top priority. Our team is:

- Conducting thorough **unit and integration testing** for all contracts
- Planning third-party **smart contract audits** prior to mainnet deployment
- Continuously reviewing code for **potential vulnerabilities**

📢 **Note:** Never use unverified smart contracts with real funds outside of testnets. Always DYOR (do your own research).

---

### Contributing

We welcome contributions from the community! Please follow these steps:

1. Fork the repository.
2. Create a new branch for your feature or fix.
3. Commit your changes with clear and descriptive messages.
4. Submit a pull request for review.

## Community

Join our vibrant community to discuss ideas, share feedback, and stay updated on the latest developments:

- **Discord:** [Arenium Official Server](https://discord.gg/ThMkW8X89k)
- **Website:** [Arenium Platform](https://www.arenium.social/)
- **Twitter:** [@AreniumApp](https://x.com/TheArenium)
- **The Arena:** [@AreniumApp](https://starsarena.com/TheArenium)

## License

This repository is licensed under the MIT License. See the `LICENSE` file for more information.

## Stay Ahead with Arenium

From memecoin trends to global events, Arenium empowers you to predict and profit with confidence. Join us in shaping the future of decentralized prediction markets!

### Why Choose Arenium?

- Decentralized and Trustless: Built on blockchain technology, Arenium ensures transparency and fairness.
- Gamified Experience: Engage in challenges, climb leaderboards, and earn rewards.
- Scalable and Efficient: Powered by Avalanche, Arenium delivers fast and cost-effective transactions.
- Community-Driven: Designed for and by The Arena community, Arenium thrives on user feedback and participation.

Let’s build the future of prediction markets together with Arenium!
