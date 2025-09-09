// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {AMMContract} from "../../src/AMMContract.sol";

/**
 * @title AMMScript
 * @author 
 * @notice This Foundry script is used to deploy or interact with an already deployed AMMContract instance.
 * @dev 
 * - The script demonstrates how to initialize a liquidity pool in the AMMContract.
 * - It connects to a pre-deployed AMM contract at a fixed address and calls `initializePool()`.
 * - Uses Foundry's `vm.startBroadcast()` and `vm.stopBroadcast()` to send actual transactions.
 * - This script is expected to be run with `forge script` commands in a Foundry environment.
 *
 * ### Workflow:
 * 1. Start broadcasting transactions (enables sending signed transactions to the network).
 * 2. Create a contract instance by referencing an already deployed AMMContract.
 * 3. Define pool parameters such as token addresses, fee, and market identifier.
 * 4. Call `initializePool()` on the AMMContract to create a new pool.
 * 5. Log the address of the AMMContract instance to the console for reference.
 * 6. Stop broadcasting transactions.
 *
 * ### Security & Safety Notes:
 * - This script will send a state-changing transaction to the network when run with the `--broadcast` flag.
 * - The hardcoded addresses for `AMMContract`, `tokenA`, and `tokenB` must point to valid contracts on the network being used.
 * - Ensure that `fee` is in the correct format and within expected bounds of the AMMContract.
 * - Re-running the script with the same parameters may revert if the pool has already been initialized.
 */
contract AMMScript is Script {
    function run() external {
        // HelperConfig helperConfig = new HelperConfig();
        vm.startBroadcast();
        AMMContract amm = AMMContract(0xE382B600D1b68d645AF14414110eEf0CFEb49Ecc);
        address tokenA = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
        address tokenB = 0x808456652fdb597867f38412077A9182bf77359F;
        uint24 fee = 5000000;
        bytes32 marketId = 0x0000000000000000000000000000000000000000000000000000000000000001;
        amm.initializePool(tokenA, tokenB, fee, marketId);
        console2.log("Pool Address: ", address(amm));
        vm.stopBroadcast();
    }
}
