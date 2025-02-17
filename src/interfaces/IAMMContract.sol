pragma solidity 0.8.16;

interface IAMMContract {
    /**
     * @notice Abstract function to create, initialize and update pool data in this contract.
     * @param _tokenA Address of the first token.
     * @param _tokenB Address of the second token.
     * @param _fee Fee tier for the pool.
     * @param _marketId Unique identifier for the prediction market.
     */
    function initializePool(
        address _tokenA,
        address _tokenB,
        uint24 _fee,
        bytes32 _marketId
    ) external returns (address poolAddress);

    /**
     * @notice Abstract function to add liquidity to a pool.
     * @param _marketId Unique identifier for the prediction market.
     * @param _user Address of the user.
     * @param _amount0 Amount of tokenA to add.
     * @param _amount1 Amount of tokenB to add.
     * @param _tickLower Lower tick bound for the liquidity position.
     * @param _tickUpper Upper tick bound for the liquidity position.
     * @return tokenId The token ID of the position.
     * @return liquidity The liquidity of the position.
     * @return amount0 The amount of tokenA in the position.
     * @return amount1 The amount of tokenB in the position.
     */
    function addLiquidity(
        bytes32 _marketId,
        address _user,
        uint256 _amount0,
        uint256 _amount1,
        int24 _tickLower,
        int24 _tickUpper
    )
        external
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    /**
     * @notice Retrieves the position details for a given token ID.
     * @param _user The ID of the position to retrieve.
     * @return operator The operator of the position.
     * @return token0 The address of the first token in the position.
     * @return token1 The address of the second token in the position.
     * @return fee The fee tier of the position.
     * @return liquidity The liquidity of the position.
     * @return tickLower The lower tick bound of the position.
     * @return tickUpper The upper tick bound of the position.
     * @return tokensOwed0 The uncollected amount of token0 owed to the position.
     * @return tokensOwed1 The uncollected amount of token1 owed to the position.
     * @return amount0 The amount of token0 in the position.
     * @return amount1 The amount of token1 in the position.
     */
    function getUserPositionInPool(
        address _user,
        bytes32 _marketId
    )
        external
        view
        returns (
            address operator,
            address token0,
            address token1,
            uint24 fee,
            uint128 liquidity,
            int24 tickLower,
            int24 tickUpper,
            uint128 tokensOwed0,
            uint128 tokensOwed1,
            uint256 amount0,
            uint256 amount1
        );
}
