// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Script, console2} from "forge-std/Script.sol";
import {PredictionMarket} from "../../src/PredictionMarket.sol";
import {AMMContract} from "../../src/AMMContract.sol";
import {HelperConfig} from "../HelperConfig.s.sol";

contract DeployAll is Script {
    function run() external returns (PredictionMarket) {
        HelperConfig helpConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config;

        config = helpConfig.getBaseSepoliaConfig();

        vm.startBroadcast();
        AMMContract amm = new AMMContract(
            config.uniswapV3Factory, config.uniswapV3SwapRouter, config.uniswapNonFungiblePositionManager
        );
        PredictionMarket market =
            new PredictionMarket(config.finder, config.currency, config.optimisticOracleV3, address(amm));
        vm.stopBroadcast();
        console2.log("PredictionMarket deployed to: ", address(market));
        console2.log("AMM deployed to: ", address(amm));
        return market;
    }
}
