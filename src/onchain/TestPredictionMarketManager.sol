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
}
