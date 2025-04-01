// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ExpandedERC20, ExpandedIERC20} from "@uma/core/contracts/common/implementation/ExpandedERC20.sol";
import {AddressWhitelist} from "@uma/core/contracts/common/implementation/AddressWhitelist.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PMLibrary} from "./lib/PMLibrary.sol";

/**
 * @title PredictionMarketFactory
 * @author Arenium Social
 * @notice Factory contract for creating prediction markets and outcome tokens
 * @dev Handles market initialization and token creation logic
 */
contract PredictionMarketFactory is Ownable {
    // Custom errors
    error MarketFactory__CallerNotWhitelisted();
    error MarketFactory__AddressAlreadyWhitelisted();
    error MarketFactory__AddressNotWhitelisted();

    // Whitelist state
    mapping(address => bool) public whitelistedAddresses;

    /**
     * @notice Constructor to initialize the factory contract
     */
    constructor() {}

    /**
     * @notice Modifier to restrict access to whitelisted addresses.
     * @dev Reverts if the caller is not in the whitelist.
     */
    modifier onlyWhitelisted() {
        if (!whitelistedAddresses[msg.sender]) {
            revert MarketFactory__CallerNotWhitelisted();
        }
        _;
    }

    /**
     * @notice Adds an address to the whitelist, allowing it to create markets.
     * @dev Only callable by the contract owner.
     * @param account Address to add to the whitelist.
     */
    function addToWhitelist(address account) external onlyOwner {
        if (whitelistedAddresses[account]) {
            revert MarketFactory__AddressAlreadyWhitelisted();
        }
        whitelistedAddresses[account] = true;
    }

    /**
     * @notice Removes an address from the whitelist, revoking its ability to create markets.
     * @dev Only callable by the contract owner.
     * @param account Address to remove from the whitelist.
     */
    function removeFromWhitelist(address account) external onlyOwner {
        if (!whitelistedAddresses[account]) {
            revert MarketFactory__AddressNotWhitelisted();
        }
        whitelistedAddresses[account] = false;
    }
}
