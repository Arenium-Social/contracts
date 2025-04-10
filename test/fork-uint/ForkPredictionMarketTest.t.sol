// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Test, console2} from "forge-std/Test.sol";
import {PredictionMarket} from "../../src/PredictionMarket.sol";
import {PMLibrary} from "../../src/lib/PMLibrary.sol";
import {AMMContract} from "../../src/AMMContract.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract ForkPredictionMarketTest is Test {
    PredictionMarket predictionMarket;
    AMMContract amm;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig activeConfig;
    string BASE_SEPOLIA_RPC_URL = vm.envString("BASE_SEPOLIA_RPC_URL");
    address owner = makeAddr("OWNER");
    uint256 fork;
    ERC20 currency;

    function setUp() public {
        helperConfig = new HelperConfig();
        activeConfig = helperConfig.getBaseSepoliaConfig();
        fork = vm.createSelectFork(BASE_SEPOLIA_RPC_URL);

        vm.startPrank(owner);
        amm = new AMMContract(
            activeConfig.uniswapV3Factory,
            activeConfig.uniswapV3SwapRouter,
            activeConfig.uniswapNonFungiblePositionManager
        );
        predictionMarket = new PredictionMarket(
            activeConfig.finder,
            activeConfig.currency,
            activeConfig.optimisticOracleV3,
            address(amm)
        );
        vm.stopPrank();

        currency = ERC20(activeConfig.usdc);

        deal(address(currency), owner, 100 * 1e18);
    }

    function test_initializeMarket() public {
        // Add the owner to the whitelist
        vm.prank(owner);
        predictionMarket.addToWhitelist(owner);

        // Define market parameters
        string memory outcome1 = "Outcome1";
        string memory outcome2 = "Outcome2";
        string memory description = "Test Market Description";
        uint256 reward = 1e18; // 1 token as reward
        uint256 requiredBond = 0.5e18; // 0.5 tokens as bond
        uint24 poolFee = 3000; // 0.3% pool fee
        string memory imageURL = "";

        // Initialize the market
        vm.prank(owner);

        currency.approve(address(predictionMarket), reward);

        vm.prank(owner);
        bytes32 marketId = predictionMarket.initializeMarket(
            outcome1,
            outcome2,
            description,
            reward,
            requiredBond,
            poolFee,
            imageURL
        );

        // Verify the market was initialized correctly
        (
            bool resolved,
            address outcome1Token,
            address outcome2Token,
            bytes memory storedOutcome1,
            bytes memory storedOutcome2
        ) = predictionMarket.getMarket(marketId);

        assertFalse(resolved, "Market should not be resolved initially");
        assertEq(storedOutcome1, bytes(outcome1), "Outcome1 does not match");
        assertEq(storedOutcome2, bytes(outcome2), "Outcome2 does not match");

        // Verify the Uniswap V3 pool was created
        AMMContract.PoolData memory poolData = amm.getPoolUsingMarketId(
            marketId
        );
        address poolAddress = poolData.pool;
        assertTrue(poolAddress != address(0), "Pool was not created");

        // Verify the reward was transferred to the contract
        uint256 contractBalance = currency.balanceOf(address(predictionMarket));
        assertEq(
            contractBalance,
            reward,
            "Reward was not transferred to the contract"
        );
    }

    function test_CreateOutcomeTokensLiquidity() public {
        // Add the owner to the whitelist
        vm.startPrank(owner);
        predictionMarket.addToWhitelist(owner);

        // Define market parameters
        string memory outcome1 = "Outcome1";
        string memory outcome2 = "Outcome2";
        string memory description = "Test Market Description";
        uint256 reward = 1e18; // 1 token as reward
        uint256 requiredBond = 0.5e18; // 0.5 tokens as bond
        uint24 poolFee = 3000; // 0.3% pool fee
        string memory imageURL = "";

        // Approve the PredictionMarket contract to spend the reward amount
        currency.approve(address(predictionMarket), reward);

        // Initialize the market
        bytes32 marketId = predictionMarket.initializeMarket(
            outcome1,
            outcome2,
            description,
            reward,
            requiredBond,
            poolFee,
            imageURL
        );

        // Get outcome token addresses
        (, address outcome1Token, address outcome2Token, , ) = predictionMarket
            .getMarket(marketId);

        // Define liquidity parameters
        uint256 tokensToCreate = 10e18; // 1 token of each outcome
        int24 tickLower = -120; // Lower tick bound
        int24 tickUpper = 120; // Upper tick bound

        // Approve tokens for creation and liquidity
        currency.approve(address(predictionMarket), tokensToCreate);

        // First, create the outcome tokens but don't add liquidity yet

        uint256 tokenId = predictionMarket.createOutcomeTokensLiquidity(
            marketId,
            tokensToCreate,
            tickLower,
            tickUpper
        );

        // Get user liquidity in market
        (
            address operator,
            address token0,
            address token1,
            uint24 fee,
            uint128 liquidity,
            uint128 tokensOwed0,
            uint128 tokensOwed1,
            uint256 amount0,
            uint256 amount1
        ) = predictionMarket.getUserLiquidityInMarket(owner, marketId);

        assertGt(liquidity, 0);
        assertGt(amount0 + amount1, 0);
        vm.stopPrank();
    }
}
