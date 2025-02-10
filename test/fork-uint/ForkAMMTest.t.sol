// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Test, console2} from "forge-std/Test.sol";
import {PredictionMarket} from "../../src/PredictionMarket.sol";
import {AMMContract} from "../../src/AMMContract.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract ForkAMMTest is Test {
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
        tokenA = ERC20(activeConfig.usdc);
        tokenB = ERC20(activeConfig.weth);
        tokenB = new ERC20("Token B", "B");
        deal(address(tokenA), owner, 10 * 1e18);
        deal(address(tokenB), owner, 10 * 1e18);
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

    function test_addLiquidity() public {
        bytes32 marketId = keccak256("TestMarket");
        vm.startPrank(owner);
        amm.initializePool(address(tokenA), address(tokenB), 3000, marketId);
        tokenA.approve(address(amm), 5 * 1e18);
        tokenB.approve(address(amm), 5 * 1e18);
        amm.addLiquidity(marketId, 5 * 1e18, 5 * 1e18, -10000, 10000);
        vm.stopPrank();
    }
}
