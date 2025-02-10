// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Test, console2} from "forge-std/Test.sol";
import {PredictionMarket} from "../../src/PredictionMarket.sol";
import {PMLibrary} from "../../src/lib/PMLibrary.sol";
import {AMMContract} from "../../src/AMMContract.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ForkPredictionMarketTest is Test {
    PredictionMarket predictionMarket;
    AMMContract amm;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig activeConfig;
    address owner = makeAddr("OWNER");
    string BASE_SEPOLIA_RPC_URL = vm.envString("BASE_SEPOLIA_RPC_URL_2");
    uint256 fork;
    ERC20 tokenA;
    ERC20 tokenB;

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
            activeConfig.finder, activeConfig.currency, activeConfig.optimisticOracleV3, address(amm)
        );
        tokenA = ERC20(activeConfig.usdc);
        tokenB = ERC20(activeConfig.weth);
        tokenB = new ERC20("Token B", "B");
        deal(address(tokenA), owner, 10 * 1e18);
        deal(address(tokenB), owner, 10 * 1e18);
        vm.stopPrank();
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

        // Initialize the market
        vm.prank(owner);

        tokenA.approve(address(predictionMarket), reward);

        vm.prank(owner);
        bytes32 marketId =
            predictionMarket.initializeMarket(outcome1, outcome2, description, reward, requiredBond, poolFee);

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
        AMMContract.PoolData memory poolData = amm.getPoolUsingMarketId(marketId);
        address poolAddress = poolData.pool;
        assertTrue(poolAddress != address(0), "Pool was not created");

        // Verify the reward was transferred to the contract
        uint256 contractBalance = tokenA.balanceOf(address(predictionMarket));
        assertEq(contractBalance, reward, "Reward was not transferred to the contract");
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

        // Approve the PredictionMarket contract to spend the reward amount
        tokenA.approve(address(predictionMarket), reward);

        // Initialize the market
        bytes32 marketId =
            predictionMarket.initializeMarket(outcome1, outcome2, description, reward, requiredBond, poolFee);

        // Get outcome token addresses
        (, address outcome1Token, address outcome2Token,,) = predictionMarket.getMarket(marketId);

        // Define liquidity parameters
        uint256 tokensToCreate = 1e18; // 1 token of each outcome
        int24 tickLower = -887220; // Lower tick bound
        int24 tickUpper = 887220; // Upper tick bound

        // Approve tokens for creation and liquidity
        tokenA.approve(address(predictionMarket), tokensToCreate);

        // First, create the outcome tokens but don't add liquidity yet
        vm.expectRevert("ERC20: insufficient allowance"); // We expect this to revert first time
        uint256 tokenId = predictionMarket.createOutcomeTokensLiquidity(marketId, tokensToCreate, tickLower, tickUpper);

        // Now approve the PredictionMarket contract to spend the outcome tokens
        ERC20(outcome1Token).approve(address(predictionMarket), tokensToCreate);
        ERC20(outcome2Token).approve(address(predictionMarket), tokensToCreate);

        // Try again with proper approvals
        tokenId = predictionMarket.createOutcomeTokensLiquidity(marketId, tokensToCreate, tickLower, tickUpper);
        // Verify the outcome tokens were created and liquidity was added
        uint256 userOutcome1Balance = ERC20(outcome1Token).balanceOf(owner);
        uint256 userOutcome2Balance = ERC20(outcome2Token).balanceOf(owner);

        // Since half the tokens should be in the liquidity pool
        assertEq(userOutcome1Balance, tokensToCreate / 2, "Outcome1 tokens were not created correctly");
        assertEq(userOutcome2Balance, tokensToCreate / 2, "Outcome2 tokens were not created correctly");

        // Verify the position exists by checking the NFT ownership
        bool success = tokenId != 0;
        assertTrue(success, "No NFT position created");

        vm.stopPrank();
    }
}
