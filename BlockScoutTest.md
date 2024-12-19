# Prediction Market Contract Testing Guide

> A comprehensive guide for testing the Prediction Market smart contract through Blockscout's read/write interface.

## Table of Contents
- [Prediction Market Contract Testing Guide](#prediction-market-contract-testing-guide)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Testing Flow](#testing-flow)
    - [1. Initial Setup \& Checks](#1-initial-setup--checks)
    - [2. Creating a Market](#2-creating-a-market)
    - [3. Verify Market Creation](#3-verify-market-creation)
    - [4. Creating Position Tokens](#4-creating-position-tokens)
    - [5. Testing Token Redemption](#5-testing-token-redemption)
    - [6. Asserting Market Outcome](#6-asserting-market-outcome)
    - [7. Settlement (After Oracle Resolution)](#7-settlement-after-oracle-resolution)
  - [Error Handling](#error-handling)
  - [Testing Tips](#testing-tips)
    - [1. Token Address Management](#1-token-address-management)
    - [2. Token Approvals](#2-token-approvals)
    - [3. Edge Cases](#3-edge-cases)
  - [License](#license)

## Prerequisites

Before beginning the testing process, ensure you have:

- Access to Blockscout explorer for your testnet
- Test ETH in your wallet for transaction fees
- Test ERC20 tokens (for the currency parameter specified in constructor)
- Contract deployed and verified on the testnet

## Testing Flow

### 1. Initial Setup & Checks

Start by verifying the basic contract setup using these read functions:

```solidity
// Check the ERC20 token address being used
getCurrency()

// Confirm assertion period (should be 7200 seconds/2 hours)
getAssertionLiveness()

// View the identifier used for the UMA oracle
getDefaultIdentifier()

// Confirm owner permissions
owner()
```

### 2. Creating a Market

Use `initializeMarket` with these parameters:

```solidity
function initializeMarket(
    string memory outcome1,    // "Yes"
    string memory outcome2,    // "No"
    string memory description, // "Will it rain tomorrow?"
    uint256 reward,           // 100000000000000000 (0.1 tokens)
    uint256 requiredBond      // 50000000000000000 (0.05 tokens)
) external returns (bytes32 marketId)
```

**Important:**
- 📝 Approve the contract to spend your ERC20 tokens first if setting a reward
- 💾 Save the returned marketId for future interactions

### 3. Verify Market Creation

Check the market details using `getMarket`:

```solidity
function getMarket(bytes32 marketId) external view returns (Market memory)
```

Verify:
- ✅ Both outcome token addresses were created
- ✅ Correct outcomes and description
- ✅ Reward and bond amounts match
- ✅ `resolved` is false
- ✅ `assertedOutcomeId` is empty

### 4. Creating Position Tokens

Create tokens using `createOutcomeTokens`:

```solidity
function createOutcomeTokens(
    bytes32 marketId,           // Your saved marketId
    uint256 tokensToCreate      // 1000000000000000000 (1 token)
)
```

**Prerequisites:**
- Approve the contract to spend your currency tokens
- Amount should be equal to the tokensToCreate parameter

### 5. Testing Token Redemption

Redeem tokens using `redeemOutcomeTokens`:

```solidity
function redeemOutcomeTokens(
    bytes32 marketId,           // Your saved marketId
    uint256 tokensToRedeem      // 500000000000000000 (0.5 tokens)
)
```

**Prerequisites:**
- Must have equal amounts of both outcome tokens
- Approve both outcome tokens to be spent by the contract

### 6. Asserting Market Outcome

Assert the market outcome using `assertMarket`:

```solidity
function assertMarket(
    bytes32 marketId,           // Your saved marketId
    string memory assertedOutcome // "Yes", "No", or use getUnresolvableOutcome()
)
```

**Prerequisites:**
- Approve the contract to spend the required bond amount
- Market must not have an active assertion
- Market must not be resolved

### 7. Settlement (After Oracle Resolution)

Settle tokens after resolution using `settleOutcomeTokens`:

```solidity
function settleOutcomeTokens(
    bytes32 marketId            // Your saved marketId
) external returns (uint256 payout)
```

**Prerequisites:**
- Market must be resolved
- Must have outcome tokens to settle

## Error Handling

Watch for these common errors:

```solidity
PredictionMarket__MarketDoesNotExist    // Invalid marketId
PredictionMarket__AssertionActiveOrResolved    // Market has active assertion
PredictionMarket__MarketNotResolved    // Settlement before resolution
PredictionMarket__InvalidAssertionOutcome    // Incorrect outcome string
```

## Testing Tips

### 1. Token Address Management
- 📋 Keep track of:
  - Currency token address
  - Both outcome token addresses for each market
  - Each marketId created

### 2. Token Approvals
Monitor approvals for:
- 💰 Currency token approvals:
  - For rewards and creating tokens
  - For assertion bonds
- 🎟️ Outcome token approvals:
  - For redemption
  - For settlement

### 3. Edge Cases
Test these scenarios:
- 🔄 Create multiple markets
- ⏱️ Try settling before resolution
- 💵 Test different reward/bond amounts
- 🎯 Test all outcomes (outcome1, outcome2, unresolvable)

## License

MIT