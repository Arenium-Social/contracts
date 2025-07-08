// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Test, console2} from "forge-std/Test.sol";
import {AMMContract} from "../../src/AMMContract.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}

contract ForkAMMTest is Test {
    AMMContract amm;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig activeConfig;
    address owner = makeAddr("OWNER");
    string BASE_SEPOLIA_RPC_URL = vm.envString("BASE_SEPOLIA_RPC_URL");
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
        tokenA = ERC20(activeConfig.usdc);
        tokenB = ERC20(activeConfig.weth);
        tokenB = new ERC20("Token B", "B");
        deal(address(tokenA), owner, 15 * 1e18);
        deal(address(tokenB), owner, 15 * 1e18);
        vm.stopPrank();
    }

    function test_initializePool() public {
        bytes32 marketId = keccak256("TestMarket");
        vm.prank(owner);
        amm.initializePool(address(tokenA), address(tokenB), 3000, marketId);
        AMMContract.PoolData memory pool = amm.getPoolUsingMarketId(marketId);
        assertEq(pool.tokenB, address(tokenB));
        assertEq(pool.tokenA, address(tokenA));
        assertEq(pool.fee, 3000);
        assertEq(pool.marketId, marketId);
        assertTrue(pool.poolInitialized);
        assertNotEq(pool.pool, address(0));
    }

    function test_mintNewPosition() public {
        bytes32 marketId = keccak256("TestMarket");
        vm.startPrank(owner);
        amm.initializePool(address(tokenA), address(tokenB), 3000, marketId);
        tokenA.approve(address(amm), 5 * 1e18);
        tokenB.approve(address(amm), 5 * 1e18);
        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
            amm.addLiquidity(marketId, owner, 5 * 1e18, 5 * 1e18, -120, 120);
        assertGt(amount0 + amount1, 0);
        assertGt(liquidity, 0);
        (address operator,,,, uint128 liquidityInPool,,,,, uint256 amount0InPool, uint256 amount1InPool) =
            amm.getUserPositionInPool(address(owner), marketId);
        assertGt(liquidityInPool, 0);
        assertGt(amount0InPool + amount1InPool, 0);
        console2.log("liquidityInPool", liquidityInPool);
        console2.log("amount0InPool", amount0InPool);
        console2.log("amount1InPool", amount1InPool);
        vm.stopPrank();
    }

    function test_increaseLiquidity() public {
        bytes32 marketId = keccak256("TestMarket");
        vm.startPrank(owner);
        amm.initializePool(address(tokenA), address(tokenB), 3000, marketId);
        tokenA.approve(address(amm), 5 * 1e18);
        tokenB.approve(address(amm), 5 * 1e18);
        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
            amm.addLiquidity(marketId, owner, 5 * 1e18, 5 * 1e18, -120, 120);
        tokenA.approve(address(amm), 5 * 1e18);
        tokenB.approve(address(amm), 5 * 1e18);
        (uint256 tokenId2, uint256 liquidity2, uint256 amount02, uint256 amount12) =
            amm.addLiquidity(marketId, owner, 5 * 1e18, 5 * 1e18, -120, 120);
        assertEq(tokenId, tokenId2);
        assertGt(liquidity2, liquidity);
        assertGt(amount02 + amount12, amount0 + amount1);
        vm.stopPrank();
    }

    function test_increaseLiquidityTwice() public {
        bytes32 marketId = keccak256("TestMarket");
        vm.startPrank(owner);
        amm.initializePool(address(tokenA), address(tokenB), 3000, marketId);
        tokenA.approve(address(amm), 5 * 1e18);
        tokenB.approve(address(amm), 5 * 1e18);
        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
            amm.addLiquidity(marketId, owner, 5 * 1e18, 5 * 1e18, -120, 120);
        tokenA.approve(address(amm), 5 * 1e18);
        tokenB.approve(address(amm), 5 * 1e18);
        (uint256 tokenId2, uint256 liquidity2, uint256 amount02, uint256 amount12) =
            amm.addLiquidity(marketId, owner, 5 * 1e18, 5 * 1e18, -120, 120);
        assertEq(tokenId, tokenId2);
        assertGt(liquidity2, liquidity);
        assertGt(amount02 + amount12, amount0 + amount1);
        tokenA.approve(address(amm), 5 * 1e18);
        tokenB.approve(address(amm), 5 * 1e18);
        (uint256 tokenId3, uint256 liquidity3, uint256 amount03, uint256 amount13) =
            amm.addLiquidity(marketId, owner, 5 * 1e18, 5 * 1e18, -120, 120);
        assertEq(tokenId, tokenId3);
        assertGt(liquidity3, liquidity2);
        assertGt(amount03 + amount13, amount02 + amount12);
        vm.stopPrank();
    }

    function test_removeLiquidity() public {
        bytes32 marketId = keccak256("TestMarket");
        vm.startPrank(owner);
        amm.initializePool(address(tokenA), address(tokenB), 3000, marketId);
        tokenA.approve(address(amm), 5 * 1e18);
        tokenB.approve(address(amm), 5 * 1e18);
        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
            amm.addLiquidity(marketId, owner, 5 * 1e18, 5 * 1e18, -120, 120);
        uint256 balBeforeTokenA = tokenA.balanceOf(address(owner));
        uint256 balBeforeTokenB = tokenB.balanceOf(address(owner));
        (uint256 amount0Decreased, uint256 amount1Decreased, uint256 amount0Collected, uint256 amount1Collected) =
            amm.removeLiquidity(marketId, owner, liquidity, 0, 0);
        assertGt(amount0Decreased + amount1Decreased, 0);
        assertGt(amount0Collected + amount1Collected, 0);
        assertGt(
            tokenA.balanceOf(address(owner)) - balBeforeTokenA + tokenB.balanceOf(address(owner)) - balBeforeTokenB, 0
        );
        vm.stopPrank();
    }

    function test_swap() public {
        MockERC20 token0 = new MockERC20("Token 0", "T0");
        MockERC20 token1 = new MockERC20("Token 1", "T1");

        bytes32 marketId = keccak256("TestMarket");
        vm.startPrank(owner);
        amm.initializePool(address(token0), address(token1), 3000, marketId);
        token0.mint(owner, 5 * 1e18);
        token1.mint(owner, 5 * 1e18);
        token0.approve(address(amm), 5 * 1e18);
        token1.approve(address(amm), 5 * 1e18);
        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) =
            amm.addLiquidity(marketId, owner, 5 * 1e18, 5 * 1e18, -120, 120);
        token0.mint(owner, 1 * 1e17);
        token0.approve(address(amm), 1 * 1e17);

        amm.swap(marketId, 1 * 1e17, 1 * 1e16, true);
        vm.stopPrank();
    }

    function test_directPoolSwap() public {
        MockERC20 token0 = new MockERC20("Token 0", "T0");
        MockERC20 token1 = new MockERC20("Token 1", "T1");

        bytes32 marketId = keccak256("TestMarket");
        vm.startPrank(owner);

        // Initialize pool
        amm.initializePool(address(token0), address(token1), 3000, marketId);

        // Mint and add liquidity
        token0.mint(owner, 5 * 1e18);
        token1.mint(owner, 5 * 1e18);
        token0.approve(address(amm), 5 * 1e18);
        token1.approve(address(amm), 5 * 1e18);
        amm.addLiquidity(marketId, owner, 5 * 1e18, 5 * 1e18, -120, 120);

        // Prepare for swap
        token0.mint(owner, 1 * 1e17);
        token0.approve(address(amm), 1 * 1e17);

        // Record balances before swap
        uint256 token0BalanceBefore = token0.balanceOf(owner);
        uint256 token1BalanceBefore = token1.balanceOf(owner);

        // Execute direct pool swap
        uint256 amountOut = amm.directPoolSwap(marketId, 1 * 1e17, 1 * 1e16, true);

        // Verify swap happened
        assertGt(amountOut, 1 * 1e16, "Output amount too low");
        assertEq(token0.balanceOf(owner), token0BalanceBefore - 1 * 1e17, "Token0 not deducted");
        assertEq(token1.balanceOf(owner), token1BalanceBefore + amountOut, "Token1 not received");

        vm.stopPrank();
    }
}
