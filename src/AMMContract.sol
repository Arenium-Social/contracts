// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

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
contract AAMContract {
    /// @notice Currency is used for token calculations
    using CurrencyLibrary for Currency;

    struct LpForMarket {
        bytes32 marketId; //Same as marketId in PredictionMarket.sol.
        bool poolActive;
        PoolKey poolKey; //Unique identifier for the pool.
        address outcome1Token;
        address outcome2Token;
    }

    struct ModifyLiquidityParams {
        // the lower and upper tick of the position
        int24 tickLower;
        int24 tickUpper;
        // how to modify the liquidity
        int256 liquidityDelta;
        // a value to set if you want unique liquidity positions at the same range
        bytes32 salt;
    }

    /// @notice Uniswap V4 pool manager
    IPoolManager public poolManager;

    mapping(bytes32 => LpForMarket) public marketIdToStruct;

    constructor(address _poolManager) {
        poolManager = IPoolManager(_poolManager);
    }

    function initializePool(
        address token0,
        address token1,
        uint24 swapFee,
        int24 tickSpacing,
        uint160 startingPrice,
        bytes32 marketId
    ) external /** OnlyPredictionMarket */ {
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }

        PoolKey memory _poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0)) // Hookless pool
        });
        poolManager.initialize(_poolKey, startingPrice);

        LpForMarket memory tempDetails = LpForMarket({
            marketId: marketId,
            poolKey: _poolKey,
            outcome1Token: token0,
            outcome2Token: token1,
            poolActive: true
        });

        marketIdToStruct[marketId] = tempDetails;
    }

    // / @param poolKey The pool to modify liquidity in
    // / @param params The parameters for modifying the liquidity
    // / @param hookData The data to pass through to the add/removeLiquidity hooks
    function addLiquidity(
        PoolKey memory poolKey,
        int24 _tickLower,
        int24 _tickUpper,
        int24 _liquidityDelta,
        bytes32 _salt,
        bytes memory hookData
    ) external {
        // ExpandedIERC20(token0).transferFrom(
        //     msg.sender,
        //     address(this),
        //     amountToken0
        // );
        // ExpandedIERC20(token1).transferFrom(
        //     msg.sender,
        //     address(this),
        //     amountToken1
        // );
        IPoolManager.ModifyLiquidityParams memory params = IPoolManager
            .ModifyLiquidityParams({
                tickLower: _tickLower,
                tickUpper: _tickUpper,
                liquidityDelta: _liquidityDelta,
                salt: _salt
            });
        poolManager.modifyLiquidity(poolKey, params, hookData);

        // uint256 totalLiquidity = amountToken0 + amountToken1;
        // liquidityProviders[msg.sender][token0].amountProvided += totalLiquidity;

        // if (
        //     liquidityProviders[msg.sender][token0].amountProvided >=
        //     liquidityThreshold
        // ) {
        //     emit LiquidityThresholdReached(token0, token1);

        //     vestingContract.setVestingSchedule(
        //         msg.sender,
        //         token0,
        //         block.timestamp,
        //         8 * 30 days,
        //         totalLiquidity
        //     );
        //     liquidityProviders[msg.sender][token0].hasVested = true;
        // }

        // emit LiquidityAdded(msg.sender, token0, token1, totalLiquidity);
    }

    function removeLiquidity() external {}
}
