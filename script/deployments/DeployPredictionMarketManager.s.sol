// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Script, console2} from "forge-std/Script.sol";
import {PredictionMarketManager} from "../../src/PredictionMarketManager.sol";
import {HelperConfig} from "../HelperConfig.s.sol";

contract DeployPredictionMarketManager is Script {
    function run() external returns (PredictionMarketManager) {
        HelperConfig helpConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config;

        config = helpConfig.getBaseSepoliaConfig();

        vm.startBroadcast();
        PredictionMarketManager market = new PredictionMarketManager();
        console2.log("PredictionMarketManager deployed to: ", address(market));
        vm.stopBroadcast();
        return market;
    }
}
