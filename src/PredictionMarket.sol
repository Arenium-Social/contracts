// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ExpandedERC20, ExpandedIERC20} from "@uma/core/contracts/common/implementation/ExpandedERC20.sol";
import {
    OracleInterfaces,
    OptimisticOracleConstraints
} from "@uma/core/contracts/data-verification-mechanism/implementation/Constants.sol";
import {AddressWhitelist} from "@uma/core/contracts/common/implementation/AddressWhitelist.sol";
import {FinderInterface} from "@uma/core/contracts/data-verification-mechanism/interfaces/FinderInterface.sol";
import {ClaimData} from "@uma/core/contracts/optimistic-oracle-v3/implementation/ClaimData.sol";
import {OptimisticOracleV3Interface} from
    "@uma/core/contracts/optimistic-oracle-v3/interfaces/OptimisticOracleV3Interface.sol";
import {OptimisticOracleV3CallbackRecipientInterface} from
    "@uma/core/contracts/optimistic-oracle-v3/interfaces/OptimisticOracleV3CallbackRecipientInterface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AMMContract} from "./AMMContract.sol";
import {PredictionMarketLib} from "./lib/PredictionMarketLib.sol";

/**
 * @title PredictionMarket
 * @author Arenium Social
 * @notice This contract allows users to create and participate in prediction markets using outcome tokens.
 * @dev The contract integrates with Uniswap V3 for liquidity provision and UMA's Optimistic Oracle V3 for dispute resolution.
 */
contract PredictionMarket is OptimisticOracleV3CallbackRecipientInterface, Ownable {
    // Custom errors
    error PredictionMarket__MarketDoesNotExist();
    error PredictionMarket__AssertionActiveOrResolved();
    error PredictionMarket__NotAuthorized();
    error PredictionMarket__MarketNotResolved();
    error PredictionMarket__EmptyOutcome();
    error PredictionMarket__OutcomesAreTheSame();
    error PredictionMarket__EmptyDescription();
    error PredictionMarket__MarketAlreadyExists();
    error PredictionMarket__InvalidAssertionOutcome();

    // Libraries
    using SafeERC20 for IERC20;
    using PredictionMarketLib for PredictionMarketLib.Market;

    // Immutable state variables
    FinderInterface public immutable finder; // UMA Finder contract to locate other UMA contracts.
    OptimisticOracleV3Interface public immutable optimisticOracle; // UMA Optimistic Oracle V3 for dispute resolution.
    AMMContract public immutable amm; // Uniswap V3 AMM contract for liquidity provision.
    IERC20 private immutable currency; // Currency token used for rewards and bonds.
    bytes32 private immutable defaultIdentifier; // Default identifier for UMA Optimistic Oracle assertions.

    // Constants
    uint64 private constant ASSERTION_LIVENESS = 7200; // 2 hours in seconds.
    bytes private constant UNRESOLVABLE = "Unresolvable"; // Outcome for unresolvable markets.
    uint256 private constant MAX_FEE = 10000; // 100% in basis points.

    // Storage
    mapping(bytes32 => PredictionMarketLib.Market) private markets; // Maps marketId to Market struct.
    mapping(bytes32 => PredictionMarketLib.AssertedMarket) private assertedMarkets; // Maps assertionId to AssertedMarket.

    // Events
    event MarketInitialized(
        bytes32 indexed marketId,
        string outcome1,
        string outcome2,
        string description,
        address outcome1Token,
        address outcome2Token,
        uint256 reward,
        uint256 requiredBond,
        uint24 poolFee
    );
    event MarketAsserted(bytes32 indexed marketId, string assertedOutcome, bytes32 indexed assertionId);
    event MarketResolved(bytes32 indexed marketId);
    event TokensCreated(bytes32 indexed marketId, address indexed account, uint256 tokensCreated);
    event TokensRedeemed(bytes32 indexed marketId, address indexed account, uint256 tokensRedeemed);
    event TokensSettled(
        bytes32 indexed marketId,
        address indexed account,
        uint256 payout,
        uint256 outcome1Tokens,
        uint256 outcome2Tokens
    );

    /**
     * @notice Constructor to initialize the contract with required dependencies.
     * @param _finder Address of the UMA Finder contract.
     * @param _currency Address of the currency token used for rewards and bonds.
     * @param _optimisticOracleV3 Address of the UMA Optimistic Oracle V3 contract.
     * @param _ammContract Address of the Uniswap V3 AMM contract.
     */
    constructor(address _finder, address _currency, address _optimisticOracleV3, address _ammContract) {
        finder = FinderInterface(_finder);
        require(_getCollateralWhitelist().isOnWhitelist(_currency), "Unsupported currency");
        currency = IERC20(_currency);
        optimisticOracle = OptimisticOracleV3Interface(_optimisticOracleV3);
        defaultIdentifier = optimisticOracle.defaultIdentifier();
        amm = AMMContract(_ammContract);
    }

    /**
     * @notice Initializes a new prediction market.
     * @dev Creates outcome tokens and initializes a Uniswap V3 pool for the market.
     * @param outcome1 Short name of the first outcome.
     * @param outcome2 Short name of the second outcome.
     * @param description Description of the market.
     * @param reward Reward available for asserting the true market outcome.
     * @param requiredBond Expected bond to assert the market outcome.
     * @param poolFee Uniswap V3 pool fee tier.
     * @return marketId Unique identifier for the market.
     */
    function initializeMarket(
        string memory outcome1,
        string memory outcome2,
        string memory description,
        uint256 reward,
        uint256 requiredBond,
        uint24 poolFee
    ) external returns (bytes32 marketId) {
        if (bytes(outcome1).length == 0) revert PredictionMarket__EmptyOutcome();
        if (bytes(outcome2).length == 0) revert PredictionMarket__EmptyOutcome();
        if (keccak256(bytes(outcome1)) == keccak256(bytes(outcome2))) {
            revert PredictionMarket__OutcomesAreTheSame();
        }
        if (bytes(description).length == 0) revert PredictionMarket__EmptyDescription();

        marketId = keccak256(abi.encode(block.number, description));
        if (markets[marketId].outcome1Token != ExpandedIERC20(address(0))) {
            revert PredictionMarket__MarketAlreadyExists();
        }

        // Create outcome tokens with this contract having minter and burner roles.
        ExpandedIERC20 outcome1Token = new ExpandedERC20(string(abi.encodePacked(outcome1, " Token")), "O1T", 18);
        ExpandedIERC20 outcome2Token = new ExpandedERC20(string(abi.encodePacked(outcome2, " Token")), "O2T", 18);
        outcome1Token.addMinter(address(this));
        outcome2Token.addMinter(address(this));
        outcome1Token.addBurner(address(this));
        outcome2Token.addBurner(address(this));

        // Store market data
        markets[marketId] = PredictionMarketLib.Market({
            resolved: false,
            assertedOutcomeId: bytes32(0),
            outcome1Token: outcome1Token,
            outcome2Token: outcome2Token,
            reward: reward,
            requiredBond: requiredBond,
            outcome1: bytes(outcome1),
            outcome2: bytes(outcome2),
            description: bytes(description),
            fee: poolFee
        });

        // Transfer reward if provided
        if (reward > 0) {
            currency.safeTransferFrom(msg.sender, address(this), reward);
        }

        // Initialize Uniswap V3 pool
        amm.initializePool(address(outcome1Token), address(outcome2Token), poolFee, marketId);

        emit MarketInitialized(
            marketId,
            outcome1,
            outcome2,
            description,
            address(outcome1Token),
            address(outcome2Token),
            reward,
            requiredBond,
            poolFee
        );
    }

    /**
     * @notice Creates outcome tokens and adds liquidity to the Uniswap V3 pool.
     * @dev The caller must approve this contract to spend the currency tokens.
     * @param marketId Unique identifier for the market.
     * @param tokensToCreate Amount of tokens to create.
     * @param tickLower Lower tick bound for the liquidity position.
     * @param tickUpper Upper tick bound for the liquidity position.
     */
    function createOutcomeTokensLiquidity(bytes32 marketId, uint256 tokensToCreate, int24 tickLower, int24 tickUpper)
        external
    {
        PredictionMarketLib.Market storage market = markets[marketId];
        if (market.outcome1Token == ExpandedIERC20(address(0))) {
            revert PredictionMarket__MarketDoesNotExist();
        }

        // Create outcome tokens
        PredictionMarketLib.createOutcomeTokens(market, msg.sender, tokensToCreate, currency);

        // Approve AMM contract to spend the outcome tokens
        market.outcome1Token.approve(address(amm), tokensToCreate);
        market.outcome2Token.approve(address(amm), tokensToCreate);

        // Add liquidity to the Uniswap V3 pool
        uint256 liquidityAmount = tokensToCreate / 2;
        amm.addLiquidity(marketId, liquidityAmount, liquidityAmount, tickLower, tickUpper);

        emit TokensCreated(marketId, msg.sender, tokensToCreate);
    }

    /**
     * @notice Burns equal amounts of outcome tokens and returns settlement currency tokens.
     * @param marketId Unique identifier for the market.
     * @param tokensToRedeem Amount of tokens to redeem.
     */
    function redeemOutcomeTokens(bytes32 marketId, uint256 tokensToRedeem) external {
        PredictionMarketLib.Market storage market = markets[marketId];
        if (market.outcome1Token == ExpandedIERC20(address(0))) {
            revert PredictionMarket__MarketDoesNotExist();
        }
        PredictionMarketLib.redeemOutcomeTokens(market, msg.sender, tokensToRedeem, currency);
        emit TokensRedeemed(marketId, msg.sender, tokensToRedeem);
    }

    /**
     * @notice Asserts the market outcome using UMA's Optimistic Oracle V3.
     * @dev Only one concurrent assertion per market is allowed.
     * @param marketId Unique identifier for the market.
     * @param assertedOutcome The outcome being asserted.
     * @return assertionId Unique identifier for the assertion.
     */
    function assertMarket(bytes32 marketId, string memory assertedOutcome) external returns (bytes32 assertionId) {
        PredictionMarketLib.Market storage market = markets[marketId];
        if (market.outcome1Token == ExpandedIERC20(address(0))) {
            revert PredictionMarket__MarketDoesNotExist();
        }
        bytes32 assertedOutcomeId = keccak256(bytes(assertedOutcome));
        if (!_isValidOutcome(assertedOutcomeId, market.outcome1, market.outcome2)) {
            revert PredictionMarket__InvalidAssertionOutcome();
        }

        market.assertedOutcomeId = assertedOutcomeId;
        uint256 minimumBond = optimisticOracle.getMinimumBond(address(currency));
        uint256 bond = market.requiredBond > minimumBond ? market.requiredBond : minimumBond;

        // Transfer bond and make the assertion
        currency.safeTransferFrom(msg.sender, address(this), bond);
        currency.forceApprove(address(optimisticOracle), bond);

        bytes memory claim = PredictionMarketLib.composeClaim(assertedOutcome, market.description, block.timestamp);
        assertionId = _assertTruthWithDefaults(claim, bond);

        // Store the asserter and marketId for the callback
        assertedMarkets[assertionId] = PredictionMarketLib.AssertedMarket({asserter: msg.sender, marketId: marketId});

        emit MarketAsserted(marketId, assertedOutcome, assertionId);
    }

    /**
     * @notice Callback function triggered when an assertion is resolved.
     * @dev If the assertion is resolved truthfully, the market is marked as resolved and the asserter receives the reward.
     * @param assertionId Unique identifier for the assertion.
     * @param assertedTruthfully Whether the assertion was resolved truthfully.
     */
    function assertionResolvedCallback(bytes32 assertionId, bool assertedTruthfully) external {
        if (msg.sender != address(optimisticOracle)) {
            revert PredictionMarket__NotAuthorized();
        }
        PredictionMarketLib.Market storage market = markets[assertedMarkets[assertionId].marketId];

        if (assertedTruthfully) {
            market.resolved = true;
            if (market.reward > 0) {
                currency.safeTransfer(assertedMarkets[assertionId].asserter, market.reward);
            }
            emit MarketResolved(assertedMarkets[assertionId].marketId);
        } else {
            market.assertedOutcomeId = bytes32(0);
        }
        delete assertedMarkets[assertionId];
    }

    /**
     * @notice Callback function triggered when an assertion is disputed.
     * @dev This function does nothing as disputes are handled by the Optimistic Oracle.
     * @param assertionId Unique identifier for the assertion.
     */
    function assertionDisputedCallback(bytes32 assertionId) external {}

    /**
     * @notice Settles outcome tokens and calculates the payout based on the resolved market outcome.
     * @param marketId Unique identifier for the market.
     * @return payout Amount of currency tokens received.
     */
    function settleOutcomeTokens(bytes32 marketId) external returns (uint256 payout) {
        PredictionMarketLib.Market storage market = markets[marketId];
        if (!market.resolved) {
            revert PredictionMarket__MarketNotResolved();
        }
        uint256 outcome1Balance = market.outcome1Token.balanceOf(msg.sender);
        uint256 outcome2Balance = market.outcome2Token.balanceOf(msg.sender);

        payout = PredictionMarketLib.calculatePayout(market, outcome1Balance, outcome2Balance);

        market.outcome1Token.burnFrom(msg.sender, outcome1Balance);
        market.outcome2Token.burnFrom(msg.sender, outcome2Balance);
        currency.safeTransfer(msg.sender, payout);

        emit TokensSettled(marketId, msg.sender, payout, outcome1Balance, outcome2Balance);
    }

    /**
     * @notice Checks if the asserted outcome is valid.
     * @param assertedOutcomeId Hashed asserted outcome.
     * @param outcome1 First outcome of the market.
     * @param outcome2 Second outcome of the market.
     * @return bool Whether the asserted outcome is valid.
     */
    function _isValidOutcome(bytes32 assertedOutcomeId, bytes memory outcome1, bytes memory outcome2)
        private
        pure
        returns (bool)
    {
        return assertedOutcomeId == keccak256(outcome1) || assertedOutcomeId == keccak256(outcome2)
            || assertedOutcomeId == keccak256(UNRESOLVABLE);
    }

    /**
     * @notice Asserts a claim with default parameters using UMA's Optimistic Oracle V3.
     * @param claim The claim to assert.
     * @param bond The bond amount for the assertion.
     * @return assertionId Unique identifier for the assertion.
     */
    function _assertTruthWithDefaults(bytes memory claim, uint256 bond) internal returns (bytes32 assertionId) {
        assertionId = optimisticOracle.assertTruth(
            claim,
            msg.sender, // Asserter
            address(this), // Callback recipient
            address(0), // No sovereign security
            ASSERTION_LIVENESS,
            currency,
            bond,
            defaultIdentifier,
            bytes32(0) // No domain
        );
    }

    /**
     * @notice Retrieves the collateral whitelist from the UMA Finder.
     * @return AddressWhitelist The collateral whitelist contract.
     */
    function _getCollateralWhitelist() internal view returns (AddressWhitelist) {
        return AddressWhitelist(finder.getImplementationAddress(OracleInterfaces.CollateralWhitelist));
    }

    /**
     * @notice Retrieves simplified market data.
     * @param marketId Unique identifier for the market.
     * @return resolved Whether the market is resolved.
     * @return outcome1Token Address of the first outcome token.
     * @return outcome2Token Address of the second outcome token.
     * @return outcome1 First outcome of the market.
     * @return outcome2 Second outcome of the market.
     */
    function getMarket(bytes32 marketId)
        external
        view
        returns (
            bool resolved,
            address outcome1Token,
            address outcome2Token,
            bytes memory outcome1,
            bytes memory outcome2
        )
    {
        PredictionMarketLib.Market storage market = markets[marketId];
        if (address(market.outcome1Token) == address(0)) {
            revert PredictionMarket__MarketDoesNotExist();
        }

        return (
            market.resolved,
            address(market.outcome1Token),
            address(market.outcome2Token),
            market.outcome1,
            market.outcome2
        );
    }

    /**
     * @notice Retrieves the address of the currency token.
     * @return address Address of the currency token.
     */
    function getCurrency() external view returns (address) {
        return address(currency);
    }

    /**
     * @notice Retrieves the assertion liveness period.
     * @return uint64 Assertion liveness period in seconds.
     */
    function getAssertionLiveness() external pure returns (uint64) {
        return ASSERTION_LIVENESS;
    }

    /**
     * @notice Retrieves the default identifier for UMA Optimistic Oracle assertions.
     * @return bytes32 Default identifier.
     */
    function getDefaultIdentifier() external view returns (bytes32) {
        return defaultIdentifier;
    }

    /**
     * @notice Retrieves the unresolvable outcome string.
     * @return string Unresolvable outcome string.
     */
    function getUnresolvableOutcome() external pure returns (string memory) {
        return string(UNRESOLVABLE);
    }
}
