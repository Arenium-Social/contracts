# Arenium

Welcome to Arenium, the cutting-edge prediction market platform built on the Avalanche network. This repository houses the core smart contracts that power Arenium, enabling a decentralized, secure, and gamified prediction market experience. Leveraging UMA’s Optimistic Oracle V3 for trustless event resolution and integrating Automated Market Maker (AMM) functionality, Arenium is designed to empower users to predict, trade, and earn rewards seamlessly. Tailored for The Arena community, Arenium combines advanced blockchain technology with a user-friendly interface to redefine prediction markets.

## Deployments

- [PredictionMarket](https://basescan.org/address/0x0000000000000000000000000000000000000000)
- [AMMContract](https://base-sepolia.blockscout.com/address/0xD12355D121eDee77DbC4D1Abdf01A965409170e4)

## Overview

### What is Arenium?

Arenium is a blockchain-based prediction market platform where users can create, participate in, and trade on the outcomes of various events. By utilizing supported tokens like USDT, USDC, BTC, and WETH, users can place bets, provide liquidity, and earn rewards. Arenium is designed to cater to The Arena community, offering a gamified and transparent platform for prediction markets. Key event categories include:

- **Memecoin Performance:** Predict the success of Arena-launched memecoins.
- **Ticket Value Markets:** Bet on key performance indicators in The Arena ecosystem.
- **Sports and E-sports:** Forecast the outcomes of matches and tournaments.
- **Politics and Global Trends:** Engage in markets covering geopolitical and societal events.
- **Community Events:** Join markets based on trending cultural or local happenings.

### Key Features

1. **Event Resolution via UMA Optimistic Oracle V3:**

   - Ensures secure and trustless settlement of event outcomes.
   - Supports off-chain data resolution for a wide range of markets.
   - Minimizes reliance on centralized oracles, enhancing decentralization.

2. **Automated Market Maker (AMM):**

   - Facilitates seamless trading of outcome tokens using a liquidity pool and pricing curve.
   - Implements dynamic token pricing based on supply and demand.
   - Ensures liquidity for all markets, enabling efficient trading.

3. **Fee Collection and Distribution:**

   - Transparent and configurable fee structure for market creation, trading, and settlement.
   - Supports treasury or community-driven fee allocation.
   - Fees are distributed fairly to incentivize participation and growth.

4. **Supported Tokens:**

   - Uses USDT, USDC, BTC, and WETH as primary tokens for placing bets, providing liquidity, and earning rewards.
   - Ensures compatibility with widely-used assets for ease of use.

5. **Community-Centric Design:**

   - Features gamified elements like leaderboards, exclusive challenges, and rewards for The Arena users.
   - Encourages community participation through decentralized governance and feedback mechanisms.

6. **Built on the Avalanche Network:**
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
  - `PredictionMarket.sol`: Manages market creation, token minting, and event resolution using UMA's Optimistic Oracle.
  - `AMMContract.sol`: Facilitates token swaps using a constant product pricing curve.
  - `FeeHandler.sol`: Aggregates and distributes fees from market actions.
  - **`lib/`**: Utility and mathematical libraries:
    - `FullMath.sol`
    - `LiquidityAmounts.sol`
    - `PredictionMarketLib.sol`
    - `TickMath.sol`
- **`test/`**: Unit tests to verify contract functionality and ensure security.
- **`script/`**: Deployment and interaction scripts for the contracts.
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
- **Twitter:** [@AreniumApp](https://x.com/AreniumApp)
- **The Arena:** [@AreniumApp](https://starsarena.com/AreniumApp)

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
