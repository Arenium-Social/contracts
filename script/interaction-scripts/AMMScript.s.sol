// // SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {UniswapV3AMMContract} from "../../src/UniswapV3AMMContract.sol";

contract AMMScript is Script {
    function run() external {
        // HelperConfig helperConfig = new HelperConfig();
        vm.startBroadcast();
        UniswapV3AMMContract amm = UniswapV3AMMContract(0xE382B600D1b68d645AF14414110eEf0CFEb49Ecc);
        address tokenA = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
        address tokenB = 0x808456652fdb597867f38412077A9182bf77359F;
        uint24 fee = 5000000;
        bytes32 marketId = 0x0000000000000000000000000000000000000000000000000000000000000001;
        address pool = amm.generateAndInitializePool(tokenA, tokenB, fee, marketId, 100000000);
        console2.log("Pool Address: ", pool);
        vm.stopBroadcast();
    }
}
