// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

library AMMStorage {
    struct UserInvestment {
        uint256 amount;
        uint256 reward;
        uint256 timestamp;
        uint256 liquidity;
    }
}
