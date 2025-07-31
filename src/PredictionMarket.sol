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
import {IAMMContract} from "./interfaces/IAMMContract.sol";
import {PMLibrary} from "./lib/PMLibrary.sol";
import {PredictionMarketManager} from "./PredictionMarketManager.sol";

/**
 * @title PredictionMarket
 * @author Arenium Social
 * @notice This contract allows users to create and participate in prediction markets using outcome tokens.
 * @dev The contract integrates with Uniswap V3 for liquidity provision and UMA's Optimistic Oracle V3 for dispute resolution.
 *      Users can create markets with two possible outcomes, mint outcome tokens backed by collateral, provide liquidity,
 *      and settle tokens for payouts once markets are resolved through UMA's optimistic oracle system.
 *
 * Key Features:
 * - Binary prediction markets with outcome tokens
 * - Integration with Uniswap V3 for automated market making
 * - UMA Optimistic Oracle V3 for decentralized dispute resolution
 * - Reward mechanism for truthful market resolution
 * - Whitelist-based market creation control
 *
 * Security Considerations:
 * - Only whitelisted addresses can create markets
 * - Market outcomes are validated through UMA's optimistic oracle
 * - Bond requirements prevent spam assertions
 * - Safe token transfers using OpenZeppelin's SafeERC20
 */
contract PredictionMarket is OptimisticOracleV3CallbackRecipientInterface, Ownable, PredictionMarketManager {
    //////////////////////////////////////////////////////////////
    //                        CUSTOM ERRORS                    //
    //////////////////////////////////////////////////////////////

    /// @dev Thrown when trying to interact with a non-existent market
    error PredictionMarket__MarketDoesNotExist();

    /// @dev Thrown when trying to assert on a market that already has an active or resolved assertion
    error PredictionMarket__AssertionActiveOrResolved();

    /// @dev Thrown when an unauthorized address tries to call a restricted function
    error PredictionMarket__NotAuthorized();

    /// @dev Thrown when trying to settle tokens on an unresolved market
    error PredictionMarket__MarketNotResolved();

    /// @dev Thrown when trying to create a market with identical outcome names
    error PredictionMarket__OutcomesAreTheSame();

    /// @dev Thrown when trying to create a market with an ID that already exists
    error PredictionMarket__MarketAlreadyExists();

    /// @dev Thrown when asserting an outcome that doesn't match either market outcome
    error PredictionMarket__InvalidAssertionOutcome();

    //////////////////////////////////////////////////////////////
    //                        LIBRARIES                        //
    //////////////////////////////////////////////////////////////

    /// @dev Using SafeERC20 for safe token transfers and approvals
    using SafeERC20 for IERC20;

    /// @dev Using PMLibrary for market-related operations and data structures
    using PMLibrary for PMLibrary.Market;

    //////////////////////////////////////////////////////////////
    //                   IMMUTABLE VARIABLES                   //
    //////////////////////////////////////////////////////////////

    /// @notice UMA Finder contract to locate other UMA contracts
    /// @dev Used to access UMA's registry of contract addresses
    FinderInterface public immutable finder;

    /// @notice UMA Optimistic Oracle V3 for dispute resolution
    /// @dev Handles truth assertions and dispute resolution for market outcomes
    OptimisticOracleV3Interface public immutable optimisticOracle;

    /// @notice Uniswap V3 AMM contract for liquidity provision
    /// @dev Manages automated market making between outcome tokens
    IAMMContract public immutable amm;

    /// @notice Currency token used for rewards and bonds
    /// @dev Must be whitelisted in UMA's collateral whitelist
    IERC20 public immutable currency;

    /// @notice Default identifier for UMA Optimistic Oracle assertions
    /// @dev Used to categorize assertion types in UMA's system
    bytes32 public immutable defaultIdentifier;

    //////////////////////////////////////////////////////////////
    //                        CONSTANTS                        //
    //////////////////////////////////////////////////////////////

    /// @notice Maximum fee that can be charged (100% in basis points)
    /// @dev Used for validation of fee parameters
    uint256 public constant MAX_FEE = 10000;

    //////////////////////////////////////////////////////////////
    //                        STORAGE                          //
    //////////////////////////////////////////////////////////////

    /// @notice Maps marketId to Market struct containing all market data
    /// @dev Private mapping to store market information
    mapping(bytes32 => PMLibrary.Market) private markets;

    /// @notice Maps assertionId to AssertedMarket struct for callback handling
    /// @dev Used to track which market and asserter correspond to each assertion
    mapping(bytes32 => PMLibrary.AssertedMarket) private assertedMarkets;

    //////////////////////////////////////////////////////////////
    //                        EVENTS                           //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Emitted when a new prediction market is initialized
     * @param marketId Unique identifier for the market
     * @param outcome1 First possible outcome of the market
     * @param outcome2 Second possible outcome of the market
     * @param description Human-readable description of the market
     * @param outcome1Token Address of the token representing outcome1
     * @param outcome2Token Address of the token representing outcome2
     * @param reward Amount of currency tokens rewarded for correct assertions
     * @param requiredBond Minimum bond required to make assertions
     * @param poolFee Uniswap V3 pool fee tier (in basis points)
     * @param imageURL URL of the market's associated image
     */
    event MarketInitialized(
        bytes32 indexed marketId,
        string outcome1,
        string outcome2,
        string description,
        address outcome1Token,
        address outcome2Token,
        uint256 reward,
        uint256 requiredBond,
        uint24 poolFee,
        string imageURL
    );

    /**
     * @notice Emitted when a market outcome is asserted
     * @param marketId Unique identifier for the market
     * @param assertedOutcome The outcome being asserted as true
     * @param assertionId Unique identifier for the assertion in UMA's system
     */
    event MarketAsserted(bytes32 indexed marketId, string assertedOutcome, bytes32 assertionId);

    /**
     * @notice Emitted when a market is resolved after successful assertion
     * @param marketId Unique identifier for the resolved market
     */
    event MarketResolved(bytes32 indexed marketId);

    /**
     * @notice Emitted when outcome tokens are created and liquidity is added
     * @param marketId Unique identifier for the market
     * @param account Address that created the tokens
     * @param tokensCreated Amount of outcome tokens created (for each outcome)
     */
    event TokensCreated(bytes32 indexed marketId, address account, uint256 tokensCreated);

    /**
     * @notice Emitted when outcome tokens are redeemed
     * @param marketId Unique identifier for the market
     * @param account Address that redeemed the tokens
     * @param tokensRedeemed Amount of outcome tokens redeemed
     */
    event TokensRedeemed(bytes32 indexed marketId, address account, uint256 tokensRedeemed);

    /**
     * @notice Emitted when outcome tokens are settled for payout
     * @param marketId Unique identifier for the market
     * @param account Address that settled the tokens
     * @param payout Amount of currency tokens received
     * @param outcome1Tokens Amount of outcome1 tokens settled
     * @param outcome2Tokens Amount of outcome2 tokens settled
     */
    event TokensSettled(
        bytes32 indexed marketId, address account, uint256 payout, uint256 outcome1Tokens, uint256 outcome2Tokens
    );

    //////////////////////////////////////////////////////////////
    //                      CONSTRUCTOR                        //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Constructor to initialize the contract with required dependencies
     * @dev Validates that the currency is whitelisted in UMA's collateral whitelist
     * @param _finder Address of the UMA Finder contract
     * @param _currency Address of the currency token used for rewards and bonds
     * @param _optimisticOracleV3 Address of the UMA Optimistic Oracle V3 contract
     * @param _ammContract Address of the Uniswap V3 AMM contract
     *
     * Requirements:
     * - _currency must be whitelisted in UMA's collateral whitelist
     * - All addresses must be valid contract addresses
     *
     * @custom:security The constructor validates currency whitelist status to ensure UMA compatibility
     */
    constructor(address _finder, address _currency, address _optimisticOracleV3, address _ammContract) {
        finder = FinderInterface(_finder);
        require(PMLibrary.getCollateralWhitelist(finder).isOnWhitelist(_currency), "Unsupported currency");
        currency = IERC20(_currency);
        optimisticOracle = OptimisticOracleV3Interface(_optimisticOracleV3);
        defaultIdentifier = optimisticOracle.defaultIdentifier();
        amm = IAMMContract(_ammContract);
    }

    //////////////////////////////////////////////////////////////
    //                   EXTERNAL FUNCTIONS                    //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Initializes a new prediction market
     * @dev Creates outcome tokens and initializes a Uniswap V3 pool for the market.
     *      Only callable by whitelisted addresses through the onlyWhitelisted modifier.
     *
     * @param outcome1 Short name of the first outcome (e.g., "YES", "BIDEN")
     * @param outcome2 Short name of the second outcome (e.g., "NO", "TRUMP")
     * @param description Human-readable description of the market question
     * @param reward Amount of currency tokens rewarded for correct market resolution
     * @param requiredBond Minimum bond required to make assertions (must be >= oracle minimum)
     * @param poolFee Uniswap V3 pool fee tier (500 = 0.05%, 3000 = 0.3%, 10000 = 1%)
     * @param imageURL URL pointing to an image representing the market
     *
     * @return marketId Unique identifier for the created market
     *
     * Requirements:
     * - Caller must be whitelisted
     * - outcome1 and outcome2 must be different
     * - Market with generated ID must not already exist
     * - If reward > 0, caller must have approved this contract to spend reward amount
     *
     * Effects:
     * - Creates two ERC20 tokens representing the outcomes
     * - Initializes a Uniswap V3 pool for the outcome tokens
     * - Transfers reward from caller to contract (if reward > 0)
     * - Stores market data in the markets mapping
     *
     * @custom:security Market ID is generated using block.number and description hash to prevent collisions
     */
    function initializeMarket(
        string memory outcome1,
        string memory outcome2,
        string memory description,
        uint256 reward,
        uint256 requiredBond,
        uint24 poolFee,
        string memory imageURL
    ) external onlyWhitelisted returns (bytes32 marketId) {
        if (keccak256(bytes(outcome1)) == keccak256(bytes(outcome2))) {
            revert PredictionMarket__OutcomesAreTheSame();
        }

        marketId = keccak256(abi.encode(block.number, description));
        if (markets[marketId].outcome1Token != ExpandedIERC20(address(0))) {
            revert PredictionMarket__MarketAlreadyExists();
        }

        // Create outcome tokens with this contract having minter and burner roles.
        (ExpandedIERC20 outcome1Token, ExpandedIERC20 outcome2Token) =
            PMLibrary.createTokensInsideInitializeMarketFunc(outcome1, outcome2);

        // Store market data
        markets[marketId] = PMLibrary.Market({
            resolved: false,
            assertedOutcomeId: bytes32(0),
            outcome1Token: outcome1Token,
            outcome2Token: outcome2Token,
            reward: reward,
            requiredBond: requiredBond,
            outcome1: bytes(outcome1),
            outcome2: bytes(outcome2),
            description: bytes(description),
            fee: poolFee,
            imageURL: bytes(imageURL)
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
            poolFee,
            imageURL
        );
    }

    /**
     * @notice Creates outcome tokens and adds liquidity to the Uniswap V3 pool
     * @dev Mints equal amounts of both outcome tokens backed by collateral and adds them as liquidity.
     *      The caller must approve this contract to spend the required currency tokens.
     *
     * @param marketId Unique identifier for the market
     * @param tokensToCreate Total amount of outcome tokens to create (split equally between outcomes)
     * @param tickLower Lower price bound for the liquidity position (as a tick)
     * @param tickUpper Upper price bound for the liquidity position (as a tick)
     *
     * @return tokenId NFT token ID representing the liquidity position
     *
     * Requirements:
     * - Market must exist
     * - Caller must have approved this contract to spend tokensToCreate amount of currency
     * - tickLower must be less than tickUpper
     * - Ticks must be valid for the pool's tick spacing
     *
     * Effects:
     * - Transfers tokensToCreate amount of currency from caller to contract
     * - Mints tokensToCreate/2 of each outcome token
     * - Adds liquidity to the Uniswap V3 pool
     * - Returns NFT representing the liquidity position to the caller
     *
     * @custom:security Tokens are minted to the contract temporarily for liquidity provision
     */
    function createOutcomeTokensLiquidity(bytes32 marketId, uint256 tokensToCreate, int24 tickLower, int24 tickUpper)
        external
        returns (uint256 tokenId)
    {
        PMLibrary.Market storage market = markets[marketId];
        if (market.outcome1Token == ExpandedIERC20(address(0))) {
            revert PredictionMarket__MarketDoesNotExist();
        }

        // Create outcome tokens and mint them to this contract so that we can add liquidity to the Uniswap V3 pool.
        PMLibrary.createOutcomeTokensInsideCreateOutcomeTokensLiquidityFunc(
            market, msg.sender, tokensToCreate, currency
        );

        uint256 liquidityAmount = tokensToCreate / 2;

        // Approve AMM contract to spend the outcome tokens
        market.outcome1Token.approve(address(amm), liquidityAmount);
        market.outcome2Token.approve(address(amm), liquidityAmount);

        // Add liquidity to the Uniswap V3 pool and get the tokenId
        (tokenId,,,) = amm.addLiquidity(marketId, msg.sender, liquidityAmount, liquidityAmount, tickLower, tickUpper);

        emit TokensCreated(marketId, msg.sender, tokensToCreate);

        return tokenId;
    }

    /**
     * @notice Asserts the market outcome using UMA's Optimistic Oracle V3
     * @dev Submits a claim about the market outcome that can be disputed within the challenge period.
     *      Only one assertion can be active per market at a time.
     *
     * @param marketId Unique identifier for the market
     * @param assertedOutcome The outcome being asserted as true (must match outcome1 or outcome2)
     *
     * @return assertionId Unique identifier for the assertion in UMA's system
     *
     * Requirements:
     * - Market must exist
     * - assertedOutcome must exactly match either outcome1 or outcome2
     * - Market must not have an active assertion
     * - Caller must have approved this contract to spend the required bond amount
     *
     * Effects:
     * - Transfers bond from caller to contract
     * - Submits assertion to UMA's Optimistic Oracle
     * - Sets market's assertedOutcomeId to track the assertion
     * - Stores assertion data for callback handling
     *
     * @custom:security Bond amount is the maximum of requiredBond and oracle minimum bond
     */
    function assertMarket(bytes32 marketId, string memory assertedOutcome) external returns (bytes32 assertionId) {
        PMLibrary.Market storage market = markets[marketId];
        if (market.outcome1Token == ExpandedIERC20(address(0))) {
            revert PredictionMarket__MarketDoesNotExist();
        }
        bytes32 assertedOutcomeId = keccak256(bytes(assertedOutcome));
        if (!PMLibrary.isValidOutcome(assertedOutcomeId, market.outcome1, market.outcome2)) {
            revert PredictionMarket__InvalidAssertionOutcome();
        }

        market.assertedOutcomeId = assertedOutcomeId;
        uint256 minimumBond = optimisticOracle.getMinimumBond(address(currency));
        uint256 bond = market.requiredBond > minimumBond ? market.requiredBond : minimumBond;

        // Transfer bond and make the assertion
        currency.safeTransferFrom(msg.sender, address(this), bond);
        currency.forceApprove(address(optimisticOracle), bond);

        bytes memory claim = PMLibrary.composeClaim(assertedOutcome, market.description, block.timestamp);

        // Use the library function to assert truth
        assertionId = PMLibrary.assertTruthWithDefaults(
            optimisticOracle, claim, msg.sender, address(this), currency, bond, defaultIdentifier
        );

        // Store the asserter and marketId for the callback
        assertedMarkets[assertionId] = PMLibrary.AssertedMarket({asserter: msg.sender, marketId: marketId});

        emit MarketAsserted(marketId, assertedOutcome, assertionId);
    }

    /**
     * @notice Callback function triggered when an assertion is resolved by UMA's Oracle
     * @dev This function is called by the Optimistic Oracle when an assertion reaches resolution.
     *      Only the oracle contract can call this function.
     *
     * @param assertionId Unique identifier for the resolved assertion
     * @param assertedTruthfully Whether the assertion was confirmed as truthful
     *
     * Requirements:
     * - Only callable by the Optimistic Oracle contract
     * - Assertion must exist in assertedMarkets mapping
     *
     * Effects:
     * - If assertion was truthful: marks market as resolved and pays reward to asserter
     * - If assertion was false: resets market's assertedOutcomeId to allow new assertions
     * - Cleans up assertion data from assertedMarkets mapping
     *
     * @custom:security Access control ensures only the oracle can trigger this callback
     */
    function assertionResolvedCallback(bytes32 assertionId, bool assertedTruthfully) external {
        if (msg.sender != address(optimisticOracle)) {
            revert PredictionMarket__NotAuthorized();
        }
        PMLibrary.Market storage market = markets[assertedMarkets[assertionId].marketId];

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
     * @notice Callback function triggered when an assertion is disputed
     * @dev This function is called by the Optimistic Oracle when an assertion is disputed.
     *      Currently implements no logic as disputes are handled entirely by the Oracle.
     *
     * @param assertionId Unique identifier for the disputed assertion
     *
     * @custom:note This function is required by the callback interface but performs no actions
     */
    function assertionDisputedCallback(bytes32 assertionId) external {}

    /**
     * @notice Settles outcome tokens and calculates the payout based on the resolved market outcome.
     * @param marketId Unique identifier for the market.
     * @return payout Amount of currency tokens received.
     */
    function settleOutcomeTokens(bytes32 marketId) external returns (uint256 payout) {
        PMLibrary.Market storage market = markets[marketId];
        if (!market.resolved) {
            revert PredictionMarket__MarketNotResolved();
        }
        uint256 outcome1Balance = market.outcome1Token.balanceOf(msg.sender);
        uint256 outcome2Balance = market.outcome2Token.balanceOf(msg.sender);

        payout = PMLibrary.calculatePayout(market, outcome1Balance, outcome2Balance);

        market.outcome1Token.burnFrom(msg.sender, outcome1Balance);
        market.outcome2Token.burnFrom(msg.sender, outcome2Balance);
        currency.safeTransfer(msg.sender, payout);

        emit TokensSettled(marketId, msg.sender, payout, outcome1Balance, outcome2Balance);
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
        PMLibrary.Market storage market = markets[marketId];
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

    function getMarketStruct(bytes32 marketId) external view returns (PMLibrary.Market memory) {
        return markets[marketId];
    }

    function getUserLiquidityInMarket(address user, bytes32 marketId)
        external
        view
        returns (
            address operator,
            address token0,
            address token1,
            uint24 fee,
            uint128 liquidity,
            uint128 tokensOwed0,
            uint128 tokensOwed1,
            uint256 amount0,
            uint256 amount1
        )
    {
        (operator, token0, token1, fee, liquidity, tokensOwed0, tokensOwed1, amount0, amount1) =
            amm.getUserPositionInPool(user, marketId);
    }
}
