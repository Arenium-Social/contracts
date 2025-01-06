// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {PoolKey} from "@v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "@v4-core/src/types/Currency.sol";
import {IHooks} from "@v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@v4-core/src/interfaces/IPoolManager.sol";
import {ExpandedERC20, ExpandedIERC20} from "@uma/core/contracts/common/implementation/ExpandedERC20.sol";

/**
 * Uniswap V2 or V3 To manage trading of outcome tokens.
 * Create liquidity pools for each market (e.g., Outcome1Token/ARENA, Outcome2Token/ARENA).
 * Automate pool creation when a new market is initialized.
 *
 * Core Functions:
 *
 * addLiquidity: Users deposit outcome tokens and base tokens to a pool.
 * removeLiquidity: Users withdraw their share of liquidity.
 * swap: Users swap between outcome tokens based on the AMM pricing curve.
 * getPrice: Calculates the price of an outcome token based on the current reserves.
 * Required State Variables:
 *
 * Reserves for Outcome1Token and Outcome2Token.
 * Liquidity shares for each provider.
 *
 */
contract AMMContract {
    /// @notice Currency is used for token calculations.
    using CurrencyLibrary for Currency;

    /// @notice Struct representing a liquidity pool for a market in PredictionMarket.
    struct LpForMarket {
        bytes32 marketId; //Same as marketId in PredictionMarket.sol.
        bool poolActive;
        PoolKey poolKey; //Unique identifier for the pool.
        address outcome1Token;
        address outcome2Token;
    }

    /// @notice Struct to pass in modify liquidity params, just an objective struct, abstract from the user.
    struct ModifyLiquidityParams {
        int24 tickLower; //The lower tick of the position.
        int24 tickUpper; //The upper tick of the position.
        int256 liquidityDelta; //How to modify the liquidity.
        bytes32 salt; //A value to set if you want unique liquidity positions at the same range.
    }

    event PoolInitialized(
        bytes32 marketId,
        address outcome1Token,
        address outcome2Token,
        uint24 swapFee,
        int24 tickSpacing,
        uint160 startingPrice
    );

    event LiquidityModified(
        PoolKey poolKey, int24 tickLower, int24 tickUpper, int256 liquidityDelta, bytes32 salt, bytes hookData
    );

    /// @notice Uniswap V4 pool manager
    IPoolManager public poolManager;

    /// @notice Mapping of marketId to LpForMarket struct, market id is the one inside PredictionMarket.
    mapping(bytes32 => LpForMarket) public marketIdToStruct;

    /**
     * @param _poolManager Uniswap V4 pool manager address for the chain this contract is deployed on.
     */
    constructor(address _poolManager) {
        poolManager = IPoolManager(_poolManager);
    }

    /**
     * @notice Initializes a liquidity pool for a market.
     * @dev Called by PredictionMarket only.
     * @param _token0 Address of the first token, i.e. Outcome1Token.
     * @param _token1 Address of the second token, i.e. Outcome2Token.
     * @param _swapFee Swap fee in hundredths of a bip.
     * @param _tickSpacing Minimum number of ticks between initialized ticks.
     * @param _startingPrice Starting price of the pool.
     * @param _marketId The marketId of the market being initialized.
     */
    function initializePool(
        address _token0,
        address _token1,
        uint24 _swapFee,
        int24 _tickSpacing,
        uint160 _startingPrice,
        bytes32 _marketId
    ) external 
    /**
     * OnlyPredictionMarket
     */
    {
        if (_token0 > _token1) {
            (_token0, _token1) = (_token1, _token0);
        }

        //Initialize the pool and pool key.
        PoolKey memory _poolKey = PoolKey({
            currency0: Currency.wrap(_token0),
            currency1: Currency.wrap(_token1),
            fee: _swapFee,
            tickSpacing: _tickSpacing,
            hooks: IHooks(address(0)) // Hookless pool
        });
        poolManager.initialize(_poolKey, _startingPrice);

        //Update the struct.
        LpForMarket memory tempDetails = LpForMarket({
            marketId: _marketId,
            poolKey: _poolKey,
            outcome1Token: _token0,
            outcome2Token: _token1,
            poolActive: true
        });
        marketIdToStruct[_marketId] = tempDetails;

        //Emit the event.
        emit PoolInitialized(_marketId, _token0, _token1, _swapFee, _tickSpacing, _startingPrice);
    }

    /**
     * @notice Mofies liquidity in a pool.
     * @param poolKey The pool to modify liquidity in.
     * @param _tickLower Idk.
     * @param _tickUpper Idk.
     * @param _liquidityDelta Idk.
     * @param _salt Idk.
     * @param hookData The data to pass through to the add/removeLiquidity hooks.
     */
    function modifyLiquidity(
        PoolKey memory poolKey,
        int24 _tickLower,
        int24 _tickUpper,
        int24 _liquidityDelta,
        bytes32 _salt,
        bytes memory hookData
    ) external {
        IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
            tickLower: _tickLower,
            tickUpper: _tickUpper,
            liquidityDelta: _liquidityDelta,
            salt: _salt
        });
        poolManager.modifyLiquidity(poolKey, params, hookData);
        emit LiquidityModified(poolKey, _tickLower, _tickUpper, _liquidityDelta, _salt, hookData);
    }

    // function removeLiquidity() external {}
}
