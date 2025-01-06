// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@uma/core/contracts/common/interfaces/AddressWhitelistInterface.sol";

contract MockAddressWhitelist is AddressWhitelistInterface {
    mapping(address => bool) private whitelist;
    address[] private whitelistArray;

    function addToWhitelist(address newElement) external override {
        require(!whitelist[newElement], "Address already on whitelist");
        whitelist[newElement] = true;
        whitelistArray.push(newElement);
    }

    function removeFromWhitelist(address newElement) external override {
        require(whitelist[newElement], "Address not on whitelist");
        whitelist[newElement] = false;

        // Remove from the array
        for (uint256 i = 0; i < whitelistArray.length; i++) {
            if (whitelistArray[i] == newElement) {
                whitelistArray[i] = whitelistArray[whitelistArray.length - 1];
                whitelistArray.pop();
                break;
            }
        }
    }

    function isOnWhitelist(address newElement) external view override returns (bool) {
        return whitelist[newElement];
    }

    function getWhitelist() external view override returns (address[] memory) {
        return whitelistArray;
    }
}
