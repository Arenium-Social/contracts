# Arenium

Welcome to Arenium! This repository contains the core smart contracts powering Arenium, a next-generation prediction market platform built on the Avalanche network. Arenium leverages UMA’s Optimistic Oracle V3 to ensure trustless event resolution and incorporates Automated Market Maker (AMM) functionality for seamless token trading. Tailored for The Arena community, Arenium delivers a secure, transparent, and gamified prediction market experience.

## Overview

### What is Arenium?

Arenium is a blockchain-powered prediction market where users can bet on the outcomes of various events using supported stablecoins and tokens such as USDT, USDC, BTC, and WETH. Designed with The Arena community in mind, Arenium combines advanced smart contract technology with a user-friendly platform for creating and participating in prediction markets. Key event categories include:

- **Memecoin Performance:** Predict the success of Arena-launched memecoins.
- **Ticket Value Markets:** Bet on key performance indicators in The Arena ecosystem.
- **Sports and E-sports:** Forecast the outcomes of matches and tournaments.
- **Politics and Global Trends:** Engage in markets covering geopolitical and societal events.
- **Community Events:** Join markets based on trending cultural or local happenings.

### Key Features

1. **Event Resolution via UMA Optimistic Oracle V3:**
   - Ensures secure and trustless settlement of event outcomes.
   - Supports off-chain data resolution for a wide range of markets.

2. **Automated Market Maker (AMM):**
   - Facilitates trading of outcome tokens using a liquidity pool and pricing curve.
   - Dynamic token pricing based on supply and demand.

3. **Fee Collection and Distribution:**
   - Transparent fee structure with configurable rates for market creation, trading, and settlement.
   - Supports treasury or community-driven fee allocation.

4. **Supported Tokens:**
   - Uses USDT, USDC, BTC, and WETH as the primary tokens for placing bets, providing liquidity, and earning rewards.

5. **Community-Centric Design:**
   - Gamified features like leaderboards and exclusive challenges for The Arena users.

6. **Built on the Avalanche Network:**
   - Low transaction costs, high scalability, and robust smart contract infrastructure.

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
  - `AMM.sol`: Facilitates token swaps using a constant product pricing curve.
  - `FeeCollector.sol`: Aggregates and distributes fees from market actions.
  - **`lib/`**: Utility and mathematical libraries:
    - `FullMath.sol`
   - `LiquidityAmounts.sol`
    - `PredictionMarketLib.sol`
    - `TickMath.sol`
- **`test/`**: Unit tests to verify contract functionality and ensure security.
- **`script/`**: Deployment and interaction scripts for the contracts.
- **`docs/`**: Documentation and specifications for smart contracts.

## Getting Started

### Contributing

We welcome contributions from the community! Please follow these steps:

1. Fork the repository.
2. Create a new branch for your feature or fix.
3. Commit your changes with clear and descriptive messages.
4. Submit a pull request for review.

## Community

Join our Discord server to discuss ideas, share feedback, and get the latest updates on Arenium:

- **Discord:** [Arenium Official Server](https://discord.gg/ThMkW8X89k)
- **Website:** [Arenium Platform](https://www.arenium.social/)

## License

This repository is licensed under the MIT License. See the `LICENSE` file for more information.

## Stay Ahead with Arenium

From memecoin trends to global events, Arenium empowers you to predict and profit with confidence. Join us in shaping the future of decentralized prediction markets!
