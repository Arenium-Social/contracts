// // SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Script, console2} from "forge-std/Script.sol";
import {MockArenaToken} from "../MockArenaToken.sol";

contract DeployMockArenaToken is Script {
    function run() external returns (MockArenaToken) {
        MockArenaToken arenaToken = new MockArenaToken("ArenaToken", "ARENA", msg.sender);
        console2.log("ArenaToken deployed to: ", address(arenaToken));
        return arenaToken;
    }
}
