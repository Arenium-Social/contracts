// // SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {AMMContract} from "../../src/AMMContract.sol";

contract DeployAMM is Script {
    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        vm.startBroadcast();
        AMMContract amm = new AMMContract(
            helperConfig.getBaseSepoliaConfig().uniswapV3Factory,
            helperConfig.getBaseSepoliaConfig().uniswapV3SwapRouter,
            helperConfig
                .getBaseSepoliaConfig()
                .uniswapNonFungiblePositionManager
        );
        console2.log("AMMContract deployed to: ", address(amm));
        vm.stopBroadcast();
    }
}
