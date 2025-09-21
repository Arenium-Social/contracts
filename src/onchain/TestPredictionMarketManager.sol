// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Test_PredictionMarketManager
 * @notice Simplified version for testing whitelist functionality
 */
contract TestPredictionMarketManager is Ownable {
    //////////////////////////////////////////////////////////////
    //                        CUSTOM ERRORS                    //
    //////////////////////////////////////////////////////////////

    error CallerNotWhitelisted();
    error AddressAlreadyWhitelisted();
    error AddressNotWhitelisted();

    //////////////////////////////////////////////////////////////
    //                        STORAGE                          //
    //////////////////////////////////////////////////////////////

    mapping(address => bool) public whitelistedAddresses;

    //////////////////////////////////////////////////////////////
    //                       MODIFIERS                         //
    //////////////////////////////////////////////////////////////

    modifier onlyWhitelisted() {
        if (!whitelistedAddresses[msg.sender]) {
            revert CallerNotWhitelisted();
        }
        _;
    }

    //////////////////////////////////////////////////////////////
    //                   EXTERNAL FUNCTIONS                    //
    //////////////////////////////////////////////////////////////

    function addToWhitelist(address account) external onlyOwner {
        if (whitelistedAddresses[account]) {
            revert AddressAlreadyWhitelisted();
        }
        whitelistedAddresses[account] = true;
    }
}
