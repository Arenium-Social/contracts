// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployPredictionMarket is Script {
    function run() external returns (PredictionMarket) {
        HelperConfig helpConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config;

        config = helpConfig.getBaseSepoliaConfig();

        vm.startBroadcast();
        PredictionMarket market =
            new PredictionMarket(msg.sender, config.finder, config.currency, config.optimisticOracleV3);
        console2.log("PredictionMarket deployed to: ", address(market));
        return market;
    }
}
