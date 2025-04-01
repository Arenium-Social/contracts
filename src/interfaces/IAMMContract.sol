// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IAMMContract {
    function initializePool(address _tokenA, address _tokenB, uint24 _fee, bytes32 _marketId)
        external
        returns (address poolAddress);

    function addLiquidity(
        bytes32 _marketId,
        address _user,
        uint256 _amount0,
        uint256 _amount1,
        int24 _tickLower,
        int24 _tickUpper
    ) external returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function removeLiquidity(
        bytes32 _marketId,
        address _user,
        uint128 _liquidity,
        uint256 _amount0Min,
        uint256 _amount1Min
    )
        external
        returns (uint256 amount0Decreased, uint256 amount1Decreased, uint256 amount0Collected, uint256 amount1Collected);

    function getUserPositionInPool(address user, bytes32 marketId)
        external
        view
        returns (
            address operator,
            address token0,
            address token1,
            uint24 fee,
            uint128 liquidity,
            uint128 tokensOwed0,
            uint128 tokensOwed1,
            uint256 amount0,
            uint256 amount1
        );

    function swap(bytes32 _marketId, uint256 _amountIn, uint256 _amountOutMinimum, bool _zeroForOne) external;

    function getPoolUsingParams(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}
