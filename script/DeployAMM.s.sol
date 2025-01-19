// // SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {UniswapV3AMMContract} from "../src/UniswapV3AMMContract.sol";

contract DeployAMM is Script {
    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        vm.startBroadcast();
<<<<<<< HEAD
        UniswapV3AMMContract amm = new UniswapV3AMMContract(helperConfig.getBaseSepoliaConfig().uniswapV3Factory);
=======
        UniswapV3AMMContract amm = new UniswapV3AMMContract(
            helperConfig.getBaseSepoliaConfig().uniswapV3Factory,
            helperConfig.getBaseSepoliaConfig().uniswapV3SwapRouter
        );
>>>>>>> origin/main
        console2.log("UniswapV3AMMContract deployed to: ", address(amm));
        vm.stopBroadcast();
    }
}
