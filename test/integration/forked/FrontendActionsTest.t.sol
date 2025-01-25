// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.16;

import {Test, console2} from "forge-std/Test.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {PredictionMarket} from "../../../src/PredictionMarket.sol";
import {UniswapV3AMMContract} from "../../../src/UniswapV3AMMContract.sol";

contract FrontendActionsTest is Test {
      HelperConfig helpConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config;

        config = helpConfig.getBaseSepoliaConfig();

        vm.startBroadcast();
        UniswapV3AMMContract amm = new UniswapV3AMMContract(config.uniswapV3Factory, config.uniswapV3SwapRouter);
        PredictionMarket market =
            new PredictionMarket(config.finder, config.currency, config.optimisticOracleV3, address(amm));
        vm.stopBroadcast();
}
