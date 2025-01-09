// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IUniswapV3Factory} from "@v3-core/contracts/interfaces/IUniswapV3Factory.sol";

//  * Uniswap V2 or V3 To manage trading of outcome tokens.
//  * Create liquidity pools for each market (e.g., Outcome1Token/ARENA, Outcome2Token/ARENA).
//  * Automate pool creation when a new market is initialized.
//  *
//  * Core Functions:
//  *
//  * addLiquidity: Users deposit outcome tokens and base tokens to a pool.
//  * removeLiquidity: Users withdraw their share of liquidity.
//  * swap: Users swap between outcome tokens based on the AMM pricing curve.
//  * getPrice: Calculates the price of an outcome token based on the current reserves.
//  * Required State Variables:
//  *
//  * Reserves for Outcome1Token and Outcome2Token.
//  * Liquidity shares for each provider.

contract UniswapV3AMMContract {
    /// @notice UniswapV3 contract instance.
    IUniswapV3Factory public magicFactory;

    event PoolCreated(address poolAddress, address tokenA, address tokenB, uint24 fee);

    constructor(IUniswapV3Factory _uniswapV3Factory) {
        magicFactory = IUniswapV3Factory(_uniswapV3Factory);
    }

    /**
     * @notice Creates a new pool using uniswap v3.
     * @param tokenA One of the two tokens in the desired pool.
     * @param tokenB The other of the two tokens in the desired pool.
     * @param fee The desired fee for the pool.
     * @return poolAddress The address of the created pool.
     */
    function generatePool(address tokenA, address tokenB, uint24 fee) external returns (address poolAddress) {
        poolAddress = magicFactory.createPool(tokenA, tokenB, fee);
        emit PoolCreated(poolAddress, tokenA, tokenB, fee);
        return poolAddress;
    }

    /**
     * @notice Returns the pool address for a given pair of tokens and a fee, or address 0 if it does not exist.
     * @param tokenA The contract address of either token0 or token1.
     * @param tokenB The contract address of the other token.
     * @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip.
     * @return pool The pool address.
     */
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool) {
        pool = magicFactory.getPool(tokenA, tokenB, fee);
        return pool;
    }
}
