// // SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {PredictionMarket} from "../../src/PredictionMarket.sol";
import {UniswapV3AMMContract} from "../../src/UniswapV3AMMContract.sol";

contract AMMScript is Script {
    function run() external returns (PredictionMarket) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config;

        vm.startBroadcast();
        UniswapV3AMMContract amm = UniswapV3AMMContract(0xE382B600D1b68d645AF14414110eEf0CFEb49Ecc);
        PredictionMarket predictionMarket =
            new PredictionMarket(config.finder, config.currency, config.optimisticOracleV3, address(amm));
        string memory tokenA = "outcome1";
        string memory tokenB = "outcome2";
        string memory description = "Test Market";
        uint256 reward = 10e18;
        uint256 requiredBond = 10e18;
        uint24 poolFee = 300;
        predictionMarket.initializeMarket(tokenA, tokenB, description, reward, requiredBond, poolFee);
        console2.log("Market Address: ", address(predictionMarket));
        vm.stopBroadcast();

        return predictionMarket;
    }
}
