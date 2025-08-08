// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PMLibrary} from "./lib/PMLibrary.sol";

/**
 * @title PredictionMarketManager
 * @author Arenium Social
 * @notice This contract manages access control for prediction market creation through a whitelist system
 * @dev Serves as a base contract for PredictionMarket, providing whitelist functionality to control
 *      who can create new prediction markets. The contract inherits from OpenZeppelin's Ownable
 *      to provide ownership-based access control for whitelist management.
 *
 * Key Features:
 * - Whitelist-based access control for market creation
 * - Owner-only whitelist management functions
 * - Gas-efficient boolean mapping for whitelist storage
 * - Comprehensive error handling with custom errors
 *
 * Architecture:
 * - Designed to be inherited by the main PredictionMarket contract
 * - Uses OpenZeppelin's battle-tested Ownable pattern
 * - Implements the principle of least privilege for market creation
 *
 * Security Considerations:
 * - Only the contract owner can modify the whitelist
 * - Prevents duplicate whitelist entries and invalid removals
 * - Uses custom errors for gas-efficient error handling
 * - No external dependencies beyond OpenZeppelin's Ownable
 *
 * @custom:security This contract implements access control to prevent unauthorized market creation
 * @custom:inheritance Designed to be inherited by PredictionMarket contract
 */
contract PredictionMarketManager is Ownable {
    //////////////////////////////////////////////////////////////
    //                        CUSTOM ERRORS                    //
    //////////////////////////////////////////////////////////////

    /**
     * @dev Thrown when a non-whitelisted address attempts to perform a whitelisted-only action
     * @custom:error Used by the onlyWhitelisted modifier to prevent unauthorized access
     */
    error MarketFactory__CallerNotWhitelisted();

    /**
     * @dev Thrown when attempting to add an address that is already whitelisted
     * @custom:error Prevents unnecessary state changes and provides clear feedback
     */
    error MarketFactory__AddressAlreadyWhitelisted();

    /**
     * @dev Thrown when attempting to remove an address that is not currently whitelisted
     * @custom:error Prevents invalid state transitions and provides clear feedback
     */
    error MarketFactory__AddressNotWhitelisted();

    //////////////////////////////////////////////////////////////
    //                        STORAGE                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Mapping to track whitelisted addresses authorized to create prediction markets
     * @dev Uses a boolean mapping for gas-efficient lookups. True indicates the address is whitelisted.
     *      Public visibility allows external contracts and users to verify whitelist status.
     *
     * Storage Layout:
     * - Key: address - The address to check whitelist status for
     * - Value: bool - True if whitelisted, false otherwise
     *
     * @custom:storage This mapping is the core of the access control system
     */
    mapping(address => bool) public whitelistedAddresses;

    /**
     * @notice Constructor to initialize the PredictionMarketManager contract
     * @dev Initializes the contract and sets the deployer as the owner through Ownable's constructor.
     *      The whitelist starts empty, requiring the owner to explicitly add authorized addresses.
     *
     * Initialization Effects:
     * - Sets msg.sender as the contract owner (via Ownable)
     * - Initializes empty whitelist mapping
     * - No addresses are whitelisted by default for security
     *
     * @custom:security The contract starts with an empty whitelist, requiring explicit authorization
     */
    constructor() {}

    //////////////////////////////////////////////////////////////
    //                       MODIFIERS                         //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Modifier to restrict function access to whitelisted addresses only
     * @dev Checks if the caller's address is in the whitelistedAddresses mapping.
     *      Reverts with a custom error if the caller is not whitelisted.
     *
     * Usage:
     * - Applied to functions that should only be callable by authorized addresses
     * - Primarily used for market creation functions in the inheriting contract
     *
     * Gas Considerations:
     * - Uses custom error for gas-efficient reverts
     * - Single SLOAD operation to check whitelist status
     *
     * Requirements:
     * - Caller must be in the whitelistedAddresses mapping with a value of true
     *
     * @custom:modifier This is the core access control mechanism for the contract
     */
    modifier onlyWhitelisted() {
        if (!whitelistedAddresses[msg.sender]) {
            revert MarketFactory__CallerNotWhitelisted();
        }
        _;
    }

    //////////////////////////////////////////////////////////////
    //                   EXTERNAL FUNCTIONS                    //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Adds an address to the whitelist, granting it permission to create prediction markets
     * @dev Only callable by the contract owner. Checks if the address is already whitelisted
     *      to prevent unnecessary state changes and provide clear error feedback.
     *
     * @param account The address to add to the whitelist
     *
     * Requirements:
     * - Caller must be the contract owner (enforced by onlyOwner modifier)
     * - The account must not already be whitelisted
     * - The account must be a valid address (non-zero)
     *
     * Effects:
     * - Sets whitelistedAddresses[account] to true
     * - Grants the account permission to use onlyWhitelisted functions
     *
     * Gas Considerations:
     * - Single SSTORE operation if account is not already whitelisted
     * - Custom error for gas-efficient reverts
     *
     * Security:
     * - Owner-only access prevents unauthorized whitelist modifications
     * - Duplicate check prevents confusion and unnecessary gas usage
     *
     * @custom:access Only callable by the contract owner
     * @custom:state-change Modifies the whitelistedAddresses mapping
     */
    function addToWhitelist(address account) external onlyOwner {
        if (whitelistedAddresses[account]) {
            revert MarketFactory__AddressAlreadyWhitelisted();
        }
        whitelistedAddresses[account] = true;
    }

    /**
     * @notice Removes an address from the whitelist, revoking its permission to create prediction markets
     * @dev Only callable by the contract owner. Checks if the address is currently whitelisted
     *      to prevent invalid state transitions and provide clear error feedback.
     *
     * @param account The address to remove from the whitelist
     *
     * Requirements:
     * - Caller must be the contract owner (enforced by onlyOwner modifier)
     * - The account must currently be whitelisted
     * - The account must be a valid address (non-zero)
     *
     * Effects:
     * - Sets whitelistedAddresses[account] to false
     * - Revokes the account's permission to use onlyWhitelisted functions
     *
     * Gas Considerations:
     * - Single SSTORE operation if account is currently whitelisted
     * - Custom error for gas-efficient reverts
     *
     * Security:
     * - Owner-only access prevents unauthorized whitelist modifications
     * - Existence check prevents confusion and provides clear error feedback
     *
     * Post-conditions:
     * - The removed address will no longer be able to call onlyWhitelisted functions
     * - Any ongoing operations by the address are not affected (only future calls)
     *
     * @custom:access Only callable by the contract owner
     * @custom:state-change Modifies the whitelistedAddresses mapping
     */
    function removeFromWhitelist(address account) external onlyOwner {
        if (!whitelistedAddresses[account]) {
            revert MarketFactory__AddressNotWhitelisted();
        }
        whitelistedAddresses[account] = false;
    }

    function isWhitelisted(address account) external view returns (bool isWhitelisted) {
        return whitelistedAddresses[account];
    }
}
