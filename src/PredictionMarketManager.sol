// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PMLibrary} from "./lib/PMLibrary.sol";

/**
 * @title PredictionMarketManager
 * @author Arenium Social
 * @notice This contract is responsible for managing prediction markets.
 * @dev The contract allows whitelisted addresses to create prediction markets.
 */
contract PredictionMarketManager is Ownable {
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
