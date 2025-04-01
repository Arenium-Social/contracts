// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ExpandedERC20, ExpandedIERC20} from "@uma/core/contracts/common/implementation/ExpandedERC20.sol";
import {ClaimData} from "@uma/core/contracts/optimistic-oracle-v3/implementation/ClaimData.sol";
import {OptimisticOracleV3Interface} from
    "@uma/core/contracts/optimistic-oracle-v3/interfaces/OptimisticOracleV3Interface.sol";

/**
 * @title PMLibrary
 * @author Arenium Social
 * @notice A library containing core logic and data structures for prediction market operations.
 * @dev This library handles payout calculations, claim composition, and outcome token management.
 */
library PMLibrary {
    using SafeERC20 for IERC20; // Enable safe ERC20 operations

    // Constants
    bytes private constant UNRESOLVABLE = "Unresolvable"; // Outcome for unresolvable markets.

    /**
     * @dev Market structure storing all relevant market data
     * @param resolved Flag indicating if market outcome is finalized
     * @param assertedOutcomeId Hashed version of the currently asserted outcome
     * @param outcome1Token ERC20 token representing exposure to first outcome
     * @param outcome2Token ERC20 token representing exposure to second outcome
     * @param reward Incentive amount for successful assertion
     * @param requiredBond Minimum collateral required to assert outcome
     * @param outcome1 Raw bytes of first outcome description
     * @param outcome2 Raw bytes of second outcome description
     * @param description Raw bytes of market description
     * @param fee Uniswap pool fee tier associated with this market
     * @param imageURL Raw bytes of market image URL
     */
    struct Market {
        bool resolved;
        bytes32 assertedOutcomeId;
        ExpandedIERC20 outcome1Token;
        ExpandedIERC20 outcome2Token;
        uint256 reward;
        uint256 requiredBond;
        bytes outcome1;
        bytes outcome2;
        bytes description;
        uint24 fee;
        bytes imageURL;
    }

    /**
     * @dev Tracks relationship between assertions and markets
     * @param asserter Address that made the assertion
     * @param marketId ID of market being asserted
     */
    struct AssertedMarket {
        address asserter;
        bytes32 marketId;
    }

    /**
     * @notice Calculates currency payout based on resolved outcome and token balances
     * @dev Payout logic:
     * - If outcome1 resolved: 100% of outcome1 tokens
     * - If outcome2 resolved: 100% of outcome2 tokens
     * - If unresolved: 50% value of both tokens
     * @param market Market reference storage pointer
     * @param outcome1Balance User's balance of outcome1 tokens
     * @param outcome2Balance User's balance of outcome2 tokens
     * @return payout Calculated currency payout amount
     */
    function calculatePayout(Market storage market, uint256 outcome1Balance, uint256 outcome2Balance)
        external
        view
        returns (uint256)
    {
        if (market.assertedOutcomeId == keccak256(market.outcome1)) {
            return outcome1Balance;
        } else if (market.assertedOutcomeId == keccak256(market.outcome2)) {
            return outcome2Balance;
        } else {
            // For unresolvable outcome, split value equally
            return (outcome1Balance + outcome2Balance) / 2;
        }
    }

    /**
     * @notice Constructs a UMA-compatible claim string with timestamp context
     * @dev Format: "As of assertion timestamp [X], the described prediction market outcome is: [Y]. The market description is: [Z]"
     * @param outcome Human-readable outcome string
     * @param description Market description bytes
     * @param timestamp Block timestamp of assertion
     * @return claimBytes Properly formatted claim bytes for Optimistic Oracle
     */
    function composeClaim(string memory outcome, bytes memory description, uint256 timestamp)
        external
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            "As of assertion timestamp ",
            ClaimData.toUtf8BytesUint(timestamp), // Convert timestamp to UTF-8 bytes
            ", the described prediction market outcome is: ",
            outcome,
            ". The market description is: ",
            description
        );
    }

    /**
     * @notice Creates outcome tokens by depositing collateral
     * @dev Mints equal amounts of both outcome tokens:
     * 1. Transfers collateral from sender
     * 2. Mints outcome1 and outcome2 tokens 1:1 with collateral to the contract
     * @param market Market reference storage pointer
     * @param sender Token creator address
     * @param tokensToCreate Amount of each outcome token to mint
     * @param currency Collateral token contract
     */
    function createOutcomeTokens(Market storage market, address sender, uint256 tokensToCreate, IERC20 currency)
        external
    {
        // Transfer collateral from creator
        currency.safeTransferFrom(sender, address(this), tokensToCreate);

        // Mint equal amounts of both outcome tokens to the contract
        market.outcome1Token.mint(address(this), tokensToCreate);
        market.outcome2Token.mint(address(this), tokensToCreate);
    }

    /**
     * @notice Redeems outcome tokens for collateral
     * @dev Burns equal amounts of both tokens and returns collateral:
     * 1. Burns outcome1 and outcome2 tokens
     * 2. Returns equivalent collateral to sender
     * @param market Market reference storage pointer
     * @param sender Token redeemer address
     * @param tokensToRedeem Amount of each outcome token to burn
     * @param currency Collateral token contract
     */
    function redeemOutcomeTokens(Market storage market, address sender, uint256 tokensToRedeem, IERC20 currency)
        external
    {
        // Burn both outcome tokens equally
        market.outcome1Token.burnFrom(sender, tokensToRedeem);
        market.outcome2Token.burnFrom(sender, tokensToRedeem);

        // Return locked collateral
        currency.safeTransfer(sender, tokensToRedeem);
    }

    /**
     * @notice Checks if the asserted outcome is valid.
     * @param assertedOutcomeId Hashed asserted outcome.
     * @param outcome1 First outcome of the market.
     * @param outcome2 Second outcome of the market.
     * @return bool Whether the asserted outcome is valid.
     */
    function isValidOutcome(bytes32 assertedOutcomeId, bytes memory outcome1, bytes memory outcome2)
        external
        pure
        returns (bool)
    {
        return assertedOutcomeId == keccak256(outcome1) || assertedOutcomeId == keccak256(outcome2)
            || assertedOutcomeId == keccak256(UNRESOLVABLE);
    }

    /**
     * @notice Retrieves the unresolvable outcome string.
     * @return string Unresolvable outcome string.
     */
    function getUnresolvableOutcome() external pure returns (string memory) {
        return string(UNRESOLVABLE);
    }
}
