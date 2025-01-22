// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ExpandedERC20, ExpandedIERC20} from "@uma/core/contracts/common/implementation/ExpandedERC20.sol";
import {ClaimData} from "@uma/core/contracts/optimistic-oracle-v3/implementation/ClaimData.sol";

library PredictionMarketLib {
    using SafeERC20 for IERC20;

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
    }

    struct AssertedMarket {
        address asserter;
        bytes32 marketId;
    }

    error PredictionMarketLib__EmptyFirstOutcome();
    error PredictionMarketLib__EmptySecondOutcome();
    error PredictionMarketLib__OutcomesAreTheSame();
    error PredictionMarketLib__EmptyDescription();
    error PredictionMarketLib__MarketAlreadyExists();
    error PredictionMarketLib__InvalidAssertionOutcome();

    function validateMarketParameters(
        string memory outcome1,
        string memory outcome2,
        string memory description,
        Market storage market
    ) external view {
        if (bytes(outcome1).length == 0) {
            revert PredictionMarketLib__EmptyFirstOutcome();
        }
        if (bytes(outcome2).length == 0) {
            revert PredictionMarketLib__EmptySecondOutcome();
        }
        bytes32 outcome1Hash = keccak256(bytes(outcome1));
        bytes32 outcome2Hash = keccak256(bytes(outcome2));
        if (outcome1Hash == outcome2Hash) {
            revert PredictionMarketLib__OutcomesAreTheSame();
        }
        if (bytes(description).length == 0) {
            revert PredictionMarketLib__EmptyDescription();
        }
        if (market.outcome1Token != ExpandedIERC20(address(0))) {
            revert PredictionMarketLib__MarketAlreadyExists();
        }
    }

    function validateAssertedOutcome(
        bytes32 assertedOutcomeId,
        bytes memory outcome1,
        bytes memory outcome2,
        bytes memory unresolvable
    ) external pure returns (bool) {
        bytes32 outcome1Hash = keccak256(outcome1);
        bytes32 outcome2Hash = keccak256(outcome2);
        bytes32 unresolvableHash = keccak256(unresolvable);

        return assertedOutcomeId == outcome1Hash || assertedOutcomeId == outcome2Hash
            || assertedOutcomeId == unresolvableHash;
    }

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
            return (outcome1Balance + outcome2Balance) / 2;
        }
    }

    function composeClaim(string memory outcome, bytes memory description, uint256 timestamp)
        external
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            "As of assertion timestamp ",
            ClaimData.toUtf8BytesUint(timestamp),
            ", the described prediction market outcome is: ",
            outcome,
            ". The market description is: ",
            description
        );
    }

    function createOutcomeTokens(Market storage market, address sender, uint256 tokensToCreate, IERC20 currency)
        external
    {
        currency.safeTransferFrom(sender, address(this), tokensToCreate);
        market.outcome1Token.mint(sender, tokensToCreate);
        market.outcome2Token.mint(sender, tokensToCreate);
    }

    function redeemOutcomeTokens(Market storage market, address sender, uint256 tokensToRedeem, IERC20 currency)
        external
    {
        market.outcome1Token.burnFrom(sender, tokensToRedeem);
        market.outcome2Token.burnFrom(sender, tokensToRedeem);
        currency.safeTransfer(sender, tokensToRedeem);
    }

    // Helper functions for the main contract's getters
    function getMarketTokenAddresses(Market storage market) external view returns (address, address) {
        return (address(market.outcome1Token), address(market.outcome2Token));
    }

    function getMarketOutcomes(Market storage market) external view returns (string memory, string memory) {
        return (string(market.outcome1), string(market.outcome2));
    }

    function getMarketStatus(Market storage market) external view returns (bool, bytes32) {
        return (market.resolved, market.assertedOutcomeId);
    }
}
