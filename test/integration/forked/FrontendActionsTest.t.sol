// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.16;

import {Test, console2} from "forge-std/Test.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {PredictionMarket} from "../../../src/PredictionMarket.sol";
import {AMMContract} from "../../../src/AMMContract.sol";
import {StdUtils} from "../../../lib/forge-std/src/StdUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FrontendActionsTest is Test {
    HelperConfig helpConfig = new HelperConfig();
    HelperConfig.NetworkConfig config;
    AMMContract amm;
    PredictionMarket market;

    address owner = address(1);
    address user = address(2);
    uint256 baseSepoliaFork;
    string BASE_SEPOLIA_RPC_URL = vm.envString("BASE_SEPOLIA_RPC_URL");

    function setUp() public {
        config = helpConfig.getBaseSepoliaConfig();
        baseSepoliaFork = vm.createSelectFork(BASE_SEPOLIA_RPC_URL);
        deal(config.currency, user, 500000000);
        vm.startPrank(owner);
        amm = new AMMContract(
            config.uniswapV3Factory,
            config.uniswapV3SwapRouter,
            config.uniswapNonFungiblePositionManager
        );
        market = new PredictionMarket(
            config.finder,
            config.currency,
            config.optimisticOracleV3,
            address(amm)
        );
        vm.stopPrank();
    }

    // function testFunction() public {
    //     vm.startPrank(user);
    //     IERC20(config.currency).approve(address(market), 500000000);
    //     bytes32 marketId = market.initializeMarket(
    //         "yes",
    //         "no",
    //         "test market",
    //         500000000, // 500 USDC reward
    //         100000000, // 100 USDC bond
    //         3000
    //     );
    //     vm.stopPrank();
    // }
}
