// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IUniswapV3Factory} from "@v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract UniswapV3AMMContract {
    IUniswapV3Factory public magicFactory;

    function generatePool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address poolAddress) {
        poolAddress = magicFactory.createPool(tokenA, tokenB, fee);
    }
}
