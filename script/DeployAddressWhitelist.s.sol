// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Script, console2} from "forge-std/Script.sol";
import {AddressWhitelist} from "@uma/core/contracts/common/implementation/AddressWhitelist.sol";

contract DeployAddressWhitelist is Script {
    function run() external returns (AddressWhitelist) {
        AddressWhitelist whitelist = new AddressWhitelist();
        console2.log("AddressWhitelist deployed to: ", address(whitelist));
        return whitelist;
    }
}
