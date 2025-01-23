# Prediction Market Frontend Integration Guide

## Overview
This Prediction Market project integrates Uniswap V3 for token trading and UMA's Optimistic Oracle V3 for market resolution. Users can create markets, trade outcome tokens, and settle markets based on resolved outcomes.

## Key Contracts

### `PredictionMarket.sol`
- Manages market creation, outcome token minting, and resolution.
- Interacts with UMA's Optimistic Oracle V3 for outcome assertion and market resolution.

### `UniswapV3AMMContract.sol`
- Automated Market Maker (AMM) for trading outcome tokens.
- Enables liquidity provision and token swaps based on predictions.

### `PredictionMarketLib.sol`
- Provides utility functions for managing markets and calculating payouts.

## User Flow

### 1. Market Creation
**Function:** `initializeMarket()`

**Parameters:**
- `outcome1`: Name of the first outcome (e.g., "Yes").
- `outcome2`: Name of the second outcome (e.g., "No").
- `description`: Market description (e.g., "Will it rain tomorrow?").
- `reward`: Reward amount in ERC20 currency tokens.
- `requiredBond`: Bond amount required for market assertion.
- `poolFee`: Fee tier for the associated Uniswap V3 pool.

**Frontend Considerations:**
- Users must approve the contract to spend the `reward` amount.
- Returns a unique `marketId` used for all future interactions.

---

### 2. Create Outcome Tokens
**Function:** `createOutcomeTokens()`

**Parameters:**
- `marketId`: The unique identifier of the market.
- `tokensToCreate`: Amount of tokens to mint.

**Frontend Considerations:**
- Users must approve the contract to spend currency tokens.
- Equal amounts of `outcome1` and `outcome2` tokens are minted.
- Tokens can be traded in the associated Uniswap V3 pool.

---

### 3. Trade Outcome Tokens
**Contract:** `UniswapV3AMMContract.sol`

**Methods:**
- `swap()`: Swap between outcome tokens based on predictions.
- `addLiquidity()`: Provide liquidity to the Uniswap pool.
- `removeLiquidity()`: Remove liquidity from the pool.

**Frontend Considerations:**
- Could use Uniswap V3 SDK for precise liquidity management (Only Idea)
- Ensure correct token approvals for liquidity provision and swaps.

---

### 4. Market Assertion
**Function:** `assertMarket()`

**Parameters:**
- `marketId`: ID of the market being asserted.
- `assertedOutcome`: Proposed outcome (`outcome1`, `outcome2`, or `Unresolvable`).

**Frontend Considerations:**
- Users must approve the contract to spend the `requiredBond` amount.
- Only one assertion is allowed per market.
- Assertions are processed through UMA's Optimistic Oracle V3.

---

### 5. Settlement and Payout
**Function:** `settleOutcomeTokens()`

**Parameters:**
- `marketId`: ID of the market being settled.

**Payout Logic:**
- If `outcome1` is resolved: Full payout for `outcome1` tokens.
- If `outcome2` is resolved: Full payout for `outcome2` tokens.
- If `Unresolvable`: Equal split between token holders.

**Frontend Considerations:**
- Users must hold outcome tokens to claim payouts.
- Settlement is only possible after market resolution.

---

## Error Handling

### Common Errors
- **Market does not exist**: Ensure the correct `marketId` is used.
- **Insufficient token approvals**: Approve enough tokens for transactions.
- **Market not resolved**: Wait for UMA Oracle resolution before settling.
- **Invalid assertion outcome**: Use valid outcome strings (`outcome1`, `outcome2`, or `Unresolvable`).

---

## Code Example

```typescript
// Example interaction flow
async function createAndTradeMarket() {
  // Approve currency tokens
  await currencyToken.approve(predictionMarketAddress, rewardAmount);

  // Initialize a new market
  const marketId = await predictionMarket.initializeMarket(
    "Team A Win", 
    "Team B Win", 
    "Football Match Outcome", 
    rewardAmount, 
    bondAmount, 
    poolFee
  );

  // Mint outcome tokens
  await predictionMarket.createOutcomeTokens(marketId, tokenAmount);

  // Trade outcome tokens on Uniswap
  await uniswapV3AMM.swap(marketId, inputAmount, minOutputAmount, zeroForOne);
}
```

## Important Notes

1. **Token Approvals**:
     - Approve the contract for all necessary ERC20 transactions (reward, bond, token minting).

2. **Market Status**:
     - Verify the market status before asserting or settling.

3. **Uniswap V3 Pools**:
     - Carefully manage liquidity and tick ranges for optimal performance.

4. **UMA Resolution**:
     - Understand the resolution and dispute process for assertions.