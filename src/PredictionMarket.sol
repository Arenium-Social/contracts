// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uma/core/contracts/common/implementation/AddressWhitelist.sol";
import "@uma/core/contracts/common/implementation/ExpandedERC20.sol";
import "@uma/core/contracts/data-verification-mechanism/implementation/Constants.sol";
import "@uma/core/contracts/data-verification-mechanism/interfaces/FinderInterface.sol";
import "@uma/core/contracts/optimistic-oracle-v3/implementation/ClaimData.sol";
import "@uma/core/contracts/optimistic-oracle-v3/interfaces/OptimisticOracleV3Interface.sol";
import "@uma/core/contracts/optimistic-oracle-v3/interfaces/OptimisticOracleV3CallbackRecipientInterface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PredictionMarket is OptimisticOracleV3CallbackRecipientInterface, Ownable {
    error PredictionMarket__UnsupportedCurrency();
    error PredictionMarket__EmptyFirstOutcome();
    error PredictionMarket__EmptySecondOutcome();
    error PredictionMarket__OutcomesAreTheSame();
    error PredictionMarket__EmptyDescription();
    error PredictionMarket__MarketAlreadyExists();
    error PredictionMarket__MarketDoesNotExist();
    error PredictionMarket__AssertionActiveOrResolved();
    error PredictionMarket__InvalidAssertionOutcome();
    error PredictionMarket__NotAuthorized();
    error PredictionMarket__MarketNotResolved();

    using SafeERC20 for IERC20;

    FinderInterface public immutable finder; // UMA protocol Finder used to discover other protocol contracts.
    OptimisticOracleV3Interface public immutable optimisticOracle;
    IERC20 public immutable currency; // Currency used for all prediction markets.
    uint64 private constant ASSERTION_LIVENESS = 7200; // 2 hours.
    bytes32 private immutable defaultIdentifier; // Identifier used for all prediction markets.
    bytes private constant UNRESOLVABLE = "Unresolvable"; // Name of the unresolvable outcome where payouts are split.

    struct Market {
        bool resolved; // True if the market has been resolved and payouts can be settled.
        bytes32 assertedOutcomeId; // Hash of asserted outcome (outcome1, outcome2 or unresolvable).
        ExpandedIERC20 outcome1Token; // ERC20 token representing the value of the first outcome.
        ExpandedIERC20 outcome2Token; // ERC20 token representing the value of the second outcome.
        uint256 reward; // Reward available for asserting true market outcome.
        uint256 requiredBond; // Expected bond to assert market outcome (optimisticOraclev3 can require higher bond).
        bytes outcome1; // Short name of the first outcome.
        bytes outcome2; // Short name of the second outcome.
        bytes description; // Description of the market.
    }

    struct AssertedMarket {
        address asserter; // Address of the asserter used for reward payout.
        bytes32 marketId; // Identifier for markets mapping.
    }

    mapping(bytes32 => Market) private markets; // Maps marketId to Market struct.
    mapping(bytes32 => AssertedMarket) private assertedMarkets; // Maps assertionId to AssertedMarket.

    event MarketInitialized(
        bytes32 indexed marketId,
        string indexed outcome1,
        string indexed outcome2,
        string description,
        address outcome1Token,
        address outcome2Token,
        uint256 reward,
        uint256 requiredBond
    );
    event MarketAsserted(bytes32 indexed marketId, string indexed assertedOutcome, bytes32 indexed assertionId);
    event MarketResolved(bytes32 indexed marketId);
    event TokensCreated(bytes32 indexed marketId, address indexed account, uint256 indexed tokensCreated);
    event TokensRedeemed(bytes32 indexed marketId, address indexed account, uint256 indexed tokensRedeemed);
    event TokensSettled(
        bytes32 indexed marketId,
        address indexed account,
        uint256 indexed payout,
        uint256 outcome1Tokens,
        uint256 outcome2Tokens
    );

    constructor(address _finder, address _currency, address _optimisticOracleV3) Ownable(msg.sender) {
        finder = FinderInterface(_finder);
        require(_getCollateralWhitelist().isOnWhitelist(_currency), PredictionMarket__UnsupportedCurrency());
        currency = IERC20(_currency);
        optimisticOracle = OptimisticOracleV3Interface(_optimisticOracleV3);
        defaultIdentifier = optimisticOracle.defaultIdentifier();
    }

    function initializeMarket(
        string memory outcome1, // Short name of the first outcome.
        string memory outcome2, // Short name of the second outcome.
        string memory description, // Description of the market.
        uint256 reward, // Reward available for asserting true market outcome.
        uint256 requiredBond // Expected bond to assert market outcome (optimisticOraclev3 can require higher bond).
    ) external returns (bytes32 marketId) {
        require(bytes(outcome1).length > 0, PredictionMarket__EmptyFirstOutcome());
        require(bytes(outcome2).length > 0, PredictionMarket__EmptySecondOutcome());
        require(keccak256(bytes(outcome1)) != keccak256(bytes(outcome2)), PredictionMarket__OutcomesAreTheSame());
        require(bytes(description).length > 0, PredictionMarket__EmptyDescription());
        marketId = keccak256(abi.encode(block.number, description));
        require(markets[marketId].outcome1Token == ExpandedIERC20(address(0)), PredictionMarket__MarketAlreadyExists());

        // Create position tokens with this contract having minter and burner roles.
        ExpandedIERC20 outcome1Token = new ExpandedERC20(string(abi.encodePacked(outcome1, " Token")), "O1T", 18);
        ExpandedIERC20 outcome2Token = new ExpandedERC20(string(abi.encodePacked(outcome2, " Token")), "O2T", 18);
        outcome1Token.addMinter(address(this));
        outcome2Token.addMinter(address(this));
        outcome1Token.addBurner(address(this));
        outcome2Token.addBurner(address(this));

        markets[marketId] = Market({
            resolved: false,
            assertedOutcomeId: bytes32(0),
            outcome1Token: outcome1Token,
            outcome2Token: outcome2Token,
            reward: reward,
            requiredBond: requiredBond,
            outcome1: bytes(outcome1),
            outcome2: bytes(outcome2),
            description: bytes(description)
        });
        if (reward > 0) currency.safeTransferFrom(msg.sender, address(this), reward); // Pull reward.

        emit MarketInitialized(
            marketId,
            outcome1,
            outcome2,
            description,
            address(outcome1Token),
            address(outcome2Token),
            reward,
            requiredBond
        );
    }

    // Assert the market with any of 3 possible outcomes: names of outcome1, outcome2 or unresolvable.
    // Only one concurrent assertion per market is allowed.
    function assertMarket(bytes32 marketId, string memory assertedOutcome) external returns (bytes32 assertionId) {
        Market storage market = markets[marketId];
        require(market.outcome1Token != ExpandedIERC20(address(0)), PredictionMarket__MarketDoesNotExist());
        bytes32 assertedOutcomeId = keccak256(bytes(assertedOutcome));
        require(market.assertedOutcomeId == bytes32(0), PredictionMarket__AssertionActiveOrResolved());
        require(
            assertedOutcomeId == keccak256(market.outcome1) || assertedOutcomeId == keccak256(market.outcome2)
                || assertedOutcomeId == keccak256(UNRESOLVABLE),
            PredictionMarket__InvalidAssertionOutcome()
        );

        market.assertedOutcomeId = assertedOutcomeId;
        uint256 minimumBond = optimisticOracle.getMinimumBond(address(currency)); // optimisticOraclev3 might require higher bond.
        uint256 bond = market.requiredBond > minimumBond ? market.requiredBond : minimumBond;
        bytes memory claim = _composeClaim(assertedOutcome, market.description);

        // Pull bond and make the assertion.
        currency.safeTransferFrom(msg.sender, address(this), bond);
        currency.forceApprove(address(optimisticOracle), bond);
        assertionId = _assertTruthWithDefaults(claim, bond);

        // Store the asserter and marketId for the assertionResolvedCallback.
        assertedMarkets[assertionId] = AssertedMarket({asserter: msg.sender, marketId: marketId});

        emit MarketAsserted(marketId, assertedOutcome, assertionId);
    }

    // Callback from settled assertion.
    // If the assertion was resolved true, then the asserter gets the reward and the market is marked as resolved.
    // Otherwise, assertedOutcomeId is reset and the market can be asserted again.
    function assertionResolvedCallback(bytes32 assertionId, bool assertedTruthfully) external {
        require(msg.sender == address(optimisticOracle), PredictionMarket__NotAuthorized());
        Market storage market = markets[assertedMarkets[assertionId].marketId];

        if (assertedTruthfully) {
            market.resolved = true;
            if (market.reward > 0) currency.safeTransfer(assertedMarkets[assertionId].asserter, market.reward);
            emit MarketResolved(assertedMarkets[assertionId].marketId);
        } else {
            market.assertedOutcomeId = bytes32(0);
        }
        delete assertedMarkets[assertionId];
    }

    // Dispute callback does nothing.
    function assertionDisputedCallback(bytes32 assertionId) external {}

    // Mints pair of tokens representing the value of outcome1 and outcome2. Trading of outcome tokens is outside of the
    // scope of this contract. The caller must approve this contract to spend the currency tokens.
    // TO-DO: We need Uniswap Trading Pairs!
    function createOutcomeTokens(bytes32 marketId, uint256 tokensToCreate) external {
        Market storage market = markets[marketId];
        require(market.outcome1Token != ExpandedIERC20(address(0)), PredictionMarket__MarketDoesNotExist());

        currency.safeTransferFrom(msg.sender, address(this), tokensToCreate);

        market.outcome1Token.mint(msg.sender, tokensToCreate);
        market.outcome2Token.mint(msg.sender, tokensToCreate);

        emit TokensCreated(marketId, msg.sender, tokensToCreate);
    }

    // Burns equal amount of outcome1 and outcome2 tokens returning settlement currency tokens.
    function redeemOutcomeTokens(bytes32 marketId, uint256 tokensToRedeem) external {
        Market storage market = markets[marketId];
        require(market.outcome1Token != ExpandedIERC20(address(0)), PredictionMarket__MarketDoesNotExist());

        market.outcome1Token.burnFrom(msg.sender, tokensToRedeem);
        market.outcome2Token.burnFrom(msg.sender, tokensToRedeem);

        currency.safeTransfer(msg.sender, tokensToRedeem);

        emit TokensRedeemed(marketId, msg.sender, tokensToRedeem);
    }

    // If the market is resolved, then all of caller's outcome tokens are burned and currency payout is made depending
    // on the resolved market outcome and the amount of outcome tokens burned. If the market was resolved to the first
    // outcome, then the payout equals balance of outcome1Token while outcome2Token provides nothing. If the market was
    // resolved to the second outcome, then the payout equals balance of outcome2Token while outcome1Token provides
    // nothing. If the market was resolved to the split outcome, then both outcome tokens provides half of their balance
    // as currency payout.
    function settleOutcomeTokens(bytes32 marketId) external returns (uint256 payout) {
        Market storage market = markets[marketId];
        require(market.resolved, PredictionMarket__MarketNotResolved());

        uint256 outcome1Balance = market.outcome1Token.balanceOf(msg.sender);
        uint256 outcome2Balance = market.outcome2Token.balanceOf(msg.sender);

        if (market.assertedOutcomeId == keccak256(market.outcome1)) payout = outcome1Balance;
        else if (market.assertedOutcomeId == keccak256(market.outcome2)) payout = outcome2Balance;
        else payout = (outcome1Balance + outcome2Balance) / 2;

        market.outcome1Token.burnFrom(msg.sender, outcome1Balance);
        market.outcome2Token.burnFrom(msg.sender, outcome2Balance);
        currency.safeTransfer(msg.sender, payout);

        emit TokensSettled(marketId, msg.sender, payout, outcome1Balance, outcome2Balance);
    }

    function _assertTruthWithDefaults(bytes memory claim, uint256 bond) internal returns (bytes32 assertionId) {
        assertionId = optimisticOracle.assertTruth(
            claim,
            msg.sender, // Asserter
            address(this), // Receive callback in this contract.
            address(0), // No sovereign security.
            ASSERTION_LIVENESS,
            currency,
            bond,
            defaultIdentifier,
            bytes32(0) // No domain.
        );
    }

    function _getCollateralWhitelist() internal view returns (AddressWhitelist) {
        return AddressWhitelist(finder.getImplementationAddress(OracleInterfaces.CollateralWhitelist));
    }

    function _composeClaim(string memory outcome, bytes memory description) internal view returns (bytes memory) {
        return abi.encodePacked(
            "As of assertion timestamp ",
            ClaimData.toUtf8BytesUint(block.timestamp),
            ", the described prediction market outcome is: ",
            outcome,
            ". The market description is: ",
            description
        );
    }

    function getMarket(bytes32 marketId) external view returns (Market memory) {
        return markets[marketId];
    }
}
