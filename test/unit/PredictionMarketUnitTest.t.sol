// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Test, console2} from "forge-std/Test.sol";
import {PredictionMarket} from "../../src/PredictionMarket.sol";
import {UniswapV3AMMContract} from "../../src/UniswapV3AMMContract.sol";
import {MockOptimisticOracleV3} from "./mocks/MockOptimisticOracleV3.sol";
import {MockFinder} from "./mocks/MockFinder.sol";
import {MockAddressWhitelist} from "./mocks/MockAddressWhitelist.sol";
import "@uma/core/contracts/common/implementation/ExpandedERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PredictionMarketUnitTest is Test {
    using SafeERC20 for IERC20;

    PredictionMarket predictionMarket;
    UniswapV3AMMContract amm;
    MockOptimisticOracleV3 mockOracle;
    MockFinder mockFinder;
    MockAddressWhitelist mockWhitelist;
    ExpandedERC20 mockCurrency;

    bytes32 private constant DEFAULT_IDENTIFIER =
        keccak256("DEFAULT_IDENTIFIER");
    uint256 private constant MINIMUM_BOND = 1 ether;

    function setUp() public {
        mockCurrency = new ExpandedERC20("MockToken", "MKT", 18);

        // Grant the Minter role to the test contract (address(this)).
        mockCurrency.addMinter(address(this));

        // Deploy mocks.
        mockOracle = new MockOptimisticOracleV3(
            DEFAULT_IDENTIFIER,
            IERC20(address(mockCurrency)),
            MINIMUM_BOND
        );
        mockFinder = new MockFinder();
        mockWhitelist = new MockAddressWhitelist();

        // Set up mock interactions.
        mockFinder.changeImplementationAddress(
            bytes32("CollateralWhitelist"),
            address(mockWhitelist)
        );
        mockWhitelist.addToWhitelist(address(mockCurrency));

        // Deploy PredictionMarket contract.
        predictionMarket = new PredictionMarket(
            address(mockFinder),
            address(mockCurrency),
            address(mockOracle),
            address(amm)
        );

        // Mint some mock currency for tests.
        mockCurrency.mint(address(this), 1_000_000 ether);
    }

    // function testInitializeMarket() public {
    //     uint256 reward = 100 ether;
    //     uint256 bond = 50 ether;
    //     uint24 fee = 500;

    //     // Approve PredictionMarket to spend currency.
    //     mockCurrency.approve(address(predictionMarket), reward);

    //     // Call initializeMarket.
    //     bytes32 marketId =
    //         predictionMarket.initializeMarket("Outcome1", "Outcome2", "Test market description", reward, bond, fee);

    //     // Validate emitted event and market state.
    //     vm.expectEmit(true, true, false, true);
    //     PredictionMarket.Market memory market = predictionMarket.getMarket(marketId);
    //     assertEq(market.resolved, false);
    //     assertEq(market.outcome1, bytes("Outcome1"));
    //     assertEq(market.outcome2, bytes("Outcome2"));
    //     assertEq(market.description, bytes("Test market description"));
    //     assertEq(market.reward, reward);
    //     assertEq(market.requiredBond, bond);
    //     assertEq(market.fee, fee);
    // }

    // function testAssertMarket() public {
    //     uint256 reward = 100 ether;
    //     uint256 bond = 50 ether;
    //     uint24 fee = 500;

    //     // Approve PredictionMarket to spend currency.
    //     mockCurrency.approve(address(predictionMarket), reward + bond);

    //     // Initialize a market.
    //     bytes32 marketId =
    //         predictionMarket.initializeMarket("Outcome1", "Outcome2", "Test market description", reward, bond, fee);

    //     // Assert the market.
    //     bytes32 assertionId = predictionMarket.assertMarket(marketId, "Outcome1");

    //     // Validate state updates and events.
    //     PredictionMarket.Market memory market = predictionMarket.getMarket(marketId);
    //     assertEq(market.assertedOutcomeId, keccak256(bytes("Outcome1")));
    // }

    // function testCreateOutcomeTokens() public {
    //     uint256 reward = 100 ether;
    //     uint256 bond = 50 ether;
    //     uint256 tokensToCreate = 1_000 ether;
    //     uint24 fee = 500;

    //     // Approve PredictionMarket to spend currency.
    //     mockCurrency.approve(address(predictionMarket), reward);

    //     // Initialize a market.
    //     bytes32 marketId =
    //         predictionMarket.initializeMarket("Outcome1", "Outcome2", "Test market description", reward, bond, fee);

    //     // Approve PredictionMarket to spend currency for token creation.
    //     mockCurrency.approve(address(predictionMarket), tokensToCreate);

    //     // Create outcome tokens.
    //     predictionMarket.createOutcomeTokens(marketId, tokensToCreate);

    //     // Validate balances of outcome tokens.
    //     PredictionMarket.Market memory market = predictionMarket.getMarket(marketId);
    //     assertEq(market.outcome1Token.balanceOf(address(this)), tokensToCreate);
    //     assertEq(market.outcome2Token.balanceOf(address(this)), tokensToCreate);
    // }

    // function testRedeemOutcomeTokens() public {
    //     uint256 reward = 100 ether;
    //     uint256 bond = 50 ether;
    //     uint256 tokensToRedeem = 500 ether;
    //     uint24 fee = 500;

    //     uint256 initialBalance = mockCurrency.balanceOf(address(this));

    //     // Approve PredictionMarket to spend currency.
    //     mockCurrency.approve(address(predictionMarket), reward);

    //     // Initialize a market.
    //     bytes32 marketId =
    //         predictionMarket.initializeMarket("Outcome1", "Outcome2", "Test market description", reward, bond, fee);

    //     // Approve and create outcome tokens.
    //     mockCurrency.approve(address(predictionMarket), tokensToRedeem * 2);
    //     predictionMarket.createOutcomeTokens(marketId, tokensToRedeem * 2);

    //     // Redeem outcome tokens.
    //     predictionMarket.redeemOutcomeTokens(marketId, tokensToRedeem);

    //     // Validate balances after redemption.
    //     PredictionMarket.Market memory market = predictionMarket.getMarket(marketId);
    //     assertEq(market.outcome1Token.balanceOf(address(this)), tokensToRedeem);
    //     assertEq(market.outcome2Token.balanceOf(address(this)), tokensToRedeem);
    //     assertEq(mockCurrency.balanceOf(address(this)), initialBalance - reward - (tokensToRedeem * 2) + tokensToRedeem);
    // }

    function testGetCurrency() public view {
        assertEq(predictionMarket.getCurrency(), address(mockCurrency));
    }

    function testGetAssertionLiveness() public view {
        assertEq(predictionMarket.getAssertionLiveness(), 7200); // 2 hours
    }

    function testGetDefaultIdentifier() public view {
        assertEq(predictionMarket.getDefaultIdentifier(), DEFAULT_IDENTIFIER);
    }

    function testGetUnresolvableOutcome() public view {
        assertEq(
            string(predictionMarket.getUnresolvableOutcome()),
            "Unresolvable"
        );
    }

    // function testGetMarketTokens() public {
    //     // Initialize a market first
    //     uint256 reward = 100 ether;
    //     uint256 bond = 50 ether;
    //     mockCurrency.approve(address(predictionMarket), reward);

    //     bytes32 marketId =
    //         predictionMarket.initializeMarket("Outcome1", "Outcome2", "Test market description", reward, bond);

    //     (address outcome1Token, address outcome2Token) = predictionMarket.getMarketTokens(marketId);

    //     // Verify tokens are valid addresses and not zero address
    //     assertTrue(outcome1Token != address(0));
    //     assertTrue(outcome2Token != address(0));

    //     // Verify these are different tokens
    //     assertTrue(outcome1Token != outcome2Token);
    // }

    // function testGetMarketTokensRevertsForNonexistentMarket() public {
    //     bytes32 nonexistentMarketId = keccak256("nonexistent");
    //     vm.expectRevert(PredictionMarket.PredictionMarket__MarketDoesNotExist.selector);
    //     predictionMarket.getMarketTokens(nonexistentMarketId);
    // }

    // function testGetMarketOutcomes() public {
    //     string memory outcome1 = "Outcome1";
    //     string memory outcome2 = "Outcome2";
    //     uint256 reward = 100 ether;
    //     uint256 bond = 50 ether;
    //     mockCurrency.approve(address(predictionMarket), reward);

    //     bytes32 marketId =
    //         predictionMarket.initializeMarket(outcome1, outcome2, "Test market description", reward, bond);

    //     (bytes memory retrievedOutcome1, bytes memory retrievedOutcome2) = predictionMarket.getMarketOutcomes(marketId);

    //     assertEq(string(retrievedOutcome1), outcome1);
    //     assertEq(string(retrievedOutcome2), outcome2);
    // }

    // function testGetMarketDescription() public {
    //     string memory description = "Test market description";
    //     uint256 reward = 100 ether;
    //     uint256 bond = 50 ether;
    //     mockCurrency.approve(address(predictionMarket), reward);

    //     bytes32 marketId = predictionMarket.initializeMarket("Outcome1", "Outcome2", description, reward, bond);

    //     bytes memory retrievedDescription = predictionMarket.getMarketDescription(marketId);
    //     assertEq(string(retrievedDescription), description);
    // }

    // function testGetMarketStatus() public {
    //     uint256 reward = 100 ether;
    //     uint256 bond = 50 ether;
    //     mockCurrency.approve(address(predictionMarket), reward);

    //     bytes32 marketId =
    //         predictionMarket.initializeMarket("Outcome1", "Outcome2", "Test market description", reward, bond);

    //     (bool resolved, bytes32 assertedOutcomeId, uint256 retrievedReward, uint256 retrievedBond) =
    //         predictionMarket.getMarketStatus(marketId);

    //     assertFalse(resolved);
    //     assertEq(assertedOutcomeId, bytes32(0));
    //     assertEq(retrievedReward, reward);
    //     assertEq(retrievedBond, bond);
    // }

    // function testGetAssertedMarket() public {
    //     // Initialize market
    //     uint256 reward = 100 ether;
    //     uint256 bond = 50 ether;
    //     mockCurrency.approve(address(predictionMarket), reward);

    //     bytes32 marketId =
    //         predictionMarket.initializeMarket("Outcome1", "Outcome2", "Test market description", reward, bond);

    //     // Assert the market
    //     mockCurrency.approve(address(predictionMarket), bond);
    //     bytes32 assertionId = predictionMarket.assertMarket(marketId, "Outcome1");

    //     (address asserter, bytes32 retrievedMarketId) = predictionMarket.getAssertedMarket(assertionId);

    //     assertEq(asserter, address(this));
    //     assertEq(retrievedMarketId, marketId);
    // }

    // function testIsMarketResolved() public {
    //     uint256 reward = 100 ether;
    //     uint256 bond = 50 ether;
    //     mockCurrency.approve(address(predictionMarket), reward);

    //     bytes32 marketId =
    //         predictionMarket.initializeMarket("Outcome1", "Outcome2", "Test market description", reward, bond);

    //     assertFalse(predictionMarket.isMarketResolved(marketId));

    //     // Assert and resolve the market
    //     mockCurrency.approve(address(predictionMarket), bond);
    //     bytes32 assertionId = predictionMarket.assertMarket(marketId, "Outcome1");

    //     // Mock oracle callback to resolve the market
    //     vm.prank(address(mockOracle));
    //     predictionMarket.assertionResolvedCallback(assertionId, true);

    //     assertTrue(predictionMarket.isMarketResolved(marketId));
    // }

    // function testGetMarketBalances() public {
    //     uint256 reward = 100 ether;
    //     uint256 bond = 50 ether;
    //     uint256 tokensToCreate = 500 ether;
    //     mockCurrency.approve(address(predictionMarket), reward);

    //     bytes32 marketId =
    //         predictionMarket.initializeMarket("Outcome1", "Outcome2", "Test market description", reward, bond);

    //     // Create outcome tokens
    //     mockCurrency.approve(address(predictionMarket), tokensToCreate);
    //     predictionMarket.createOutcomeTokens(marketId, tokensToCreate);

    //     (uint256 outcome1Balance, uint256 outcome2Balance) = predictionMarket.getMarketBalances(marketId, address(this));

    //     assertEq(outcome1Balance, tokensToCreate);
    //     assertEq(outcome2Balance, tokensToCreate);
    // }

    // Will add additional tests for other contract methods.
}
