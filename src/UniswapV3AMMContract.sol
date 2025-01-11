// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IUniswapV3Factory} from "@v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3PoolActions} from "@v3-core/contracts/interfaces/pool/IUniswapV3PoolActions.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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
    IUniswapV3Factory public immutable magicFactory;
    //ISwapRouter public immutable swapRouter;

    // error UniswapV3AMMContract__TokensMustBeDifferent();
    // error UniswapV3AMMContract__PoolAlreadyExists();
    // error UniswapV3AMMContract__PoolCreationFailed();

    /// @notice Struct to store pool data.
    struct PoolData {
        bytes32 marketId;
        address pool;
        address tokenA;
        address tokenB;
        uint24 fee;
        bool poolInitialized;
    }

    /// @notice An array for all the pool datas, useful for storing all pools in this contract for testing.
    PoolData[] public pools;

    /// @notice Mapping of marketId to pool data struct.
    mapping(bytes32 => PoolData) public marketIdToPool;

    /// @notice Mapping of pool address to pool data struct, just for simplifying contract logic.
    mapping(address => PoolData) public addressToPool;

    event PoolCreated(
        address poolAddress,
        address tokenA,
        address tokenB,
        uint24 fee
    );

    event PoolInitialized(address poolAddress, uint160 sqrtPriceX96);

    constructor(address _uniswapV3Factory) {
        magicFactory = IUniswapV3Factory(_uniswapV3Factory);
        //swapRouter = ISwapRouter(_swapRouter);
    }

    /**
     * @notice Creates a new pool using uniswap v3 and initializes it.
     * @param tokenA One of the two tokens in the desired pool.
     * @param tokenB The other of the two tokens in the desired pool.
     * @param fee The desired fee for the pool.
     * @param marketId The id of the market coming from PredictionMarket.sol.
     * @param sqrtPriceX96 The initial sqrt price of the pool.
     * @return poolAddress The address of the created pool.
     */
    function generateAndInitializePool(
        address tokenA,
        address tokenB,
        uint24 fee,
        bytes32 marketId,
        uint160 sqrtPriceX96
    ) external returns (address poolAddress) {
        require(tokenA != tokenB, "Tokens Must Be Different");
        require(
            marketIdToPool[marketId].pool == address(0),
            "Pool Already Exists"
        );

        //Ensure token order for pool creation.
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        //Create pool.
        poolAddress = magicFactory.createPool(tokenA, tokenB, fee);
        require(poolAddress != address(0), "Pool Creation Failed");

        //Update pool data in this contract.
        PoolData memory temp = PoolData({
            marketId: marketId,
            pool: poolAddress,
            tokenA: tokenA,
            tokenB: tokenB,
            fee: fee,
            poolInitialized: false
        });
        pools.push(temp);
        marketIdToPool[marketId] = temp;
        addressToPool[poolAddress] = temp;

        emit PoolCreated(poolAddress, tokenA, tokenB, fee);

        //Initialize pool.
        initializePool(poolAddress, sqrtPriceX96);
    }

    /**
     * @notice Initializes a pool using uniswap v3.
     * @notice Called after generatePool is done.
     * @dev Visibility is public as to aid in testing flow.
     * @param pool Address of the pool.
     * @param sqrtPriceX96 The initial sqrt price of the pool.
     */
    function initializePool(address pool, uint160 sqrtPriceX96) public {
        require(addressToPool[pool].pool == pool, "Pool Does Not Exist");
        require(
            addressToPool[pool].poolInitialized == false,
            "Pool Already Initialized"
        );
        IUniswapV3PoolActions(pool).initialize(sqrtPriceX96);
        addressToPool[pool].poolInitialized = true;
        emit PoolInitialized(pool, sqrtPriceX96);
    }

    /// @notice Adds liquidity for the given recipient/tickLower/tickUpper position
    /// @dev The caller of this method receives a callback in the form of IUniswapV3MintCallback#uniswapV3MintCallback
    /// in which they must pay any token0 or token1 owed for the liquidity. The amount of token0/token1 due depends
    /// on tickLower, tickUpper, the amount of liquidity, and the current price.
    /// @param recipient The address for which the liquidity will be created
    /// @param tickLower The lower tick of the position in which to add liquidity
    /// @param tickUpper The upper tick of the position in which to add liquidity
    /// @param amount The amount of liquidity to mint
    /// @return amount0 The amount of token0 that was paid to mint the given amount of liquidity. Matches the value in the callback
    /// @return amount1 The amount of token1 that was paid to mint the given amount of liquidity. Matches the value in the callback
    function mintPosition(
        address pool,
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = IUniswapV3PoolActions(pool).mint(
            recipient,
            tickLower,
            tickUpper,
            amount,
            ""
        );
    }

    /**
     * @notice Returns the pool address for a given pair of tokens and a fee, or address 0 if it does not exist.
     * @dev Calls it straight from uniswap, dosen't use this contract's data.
     * @param tokenA The contract address of either token0 or token1.
     * @param tokenB The contract address of the other token.
     * @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip.
     * @return pool The pool address.
     */
    function getPoolUsingParams(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool) {
        pool = magicFactory.getPool(tokenA, tokenB, fee);
        return pool;
    }

    /**
     * @notice Returns the pool data for a given marketId, or address 0 if it does not exist.
     * @param marketId The id of the market coming from PredictionMarket.sol.
     * @return pool The struct PoolData for the given marketId.
     */
    function getPoolUsingMarketId(
        bytes32 marketId
    ) external view returns (PoolData memory pool) {
        pool = marketIdToPool[marketId];
        return pool;
    }

    /**
     * @param poolAddress The address of the pool.
     * @return pool The struct PoolData for the given pool address.
     */
    function getPoolUsingAddress(
        address poolAddress
    ) external view returns (PoolData memory pool) {
        pool = addressToPool[poolAddress];
        return pool;
    }

    /**
     * @notice Returns all the uniswap v3 pools generated using this contract.
     * @return pools An array of PoolData structs.
     */
    function getAllPools() external view returns (PoolData[] memory) {
        return pools;
    }
}
