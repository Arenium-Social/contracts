// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Script, console2} from "forge-std/Script.sol";
import {PredictionMarket} from "../../src/PredictionMarket.sol";
import {AddressWhitelist} from "@uma/core/contracts/common/implementation/AddressWhitelist.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployPredictionMarket is Script {
    function run() external returns (PredictionMarket) {
        HelperConfig helpConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config;

        if (block.chainid == 31_337) {
            config = helpConfig.getAnvilConfig();
        } else if (block.chainid == 11_155_111) {
            config = helpConfig.getSepoliaConfig();
        } else {
            revert("Unsupported network");
        }

        vm.startBroadcast();
        // Use the existing AddressWhitelist instance
        // AddressWhitelist whitelist = AddressWhitelist(0xC7f2Cf4845C6db0e1a1e91ED41Bcd0FcC1b0E141);

        // Add your token to the existing whitelist
        // whitelist.addToWhitelist(config.currency);
        PredictionMarket market = new PredictionMarket(config.finder, config.currency, config.optimisticOracleV3);
        console2.log("PredictionMarket deployed to: ", address(market));
        return market;
    }
}
