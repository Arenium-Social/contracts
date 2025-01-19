// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IUniswapV3Factory} from "@v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3SwapCallback} from "@v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./lib/ISwapRouter.sol";
import "./lib/LiquidityAmounts.sol";
import "./lib/TickMath.sol";

/**
 * @title UniswapV3AMMContract.
 * @author Arenium Social.
 * @notice Contract to manage trading of outcome tokens coming from prediction market, using uniswap V3 liquidity pools.
 * @dev Pool creation is automated when a new market is initialized in prediction market.
 */
contract UniswapV3AMMContract {
    IUniswapV3Factory public immutable magicFactory;
    ISwapRouter public immutable swapRouter;

    struct PoolData {
        bytes32 marketId;
        address pool;
        address tokenA;
        address tokenB;
        uint24 fee;
        bool poolInitialized;
    }

    PoolData[] public pools;
    mapping(bytes32 => PoolData) public marketPools;
    mapping(address => PoolData) public addressToPool;
    mapping(address => mapping(address => address)) public directPools; // Direct pool mapping for advanced access.

<<<<<<< HEAD
    event PoolCreated(address poolAddress, address tokenA, address tokenB, uint24 fee);
=======
    event PoolInitialized(bytes32 indexed marketId, address indexed pool, address tokenA, address tokenB, uint24 fee);

    event LiquidityAdded(bytes32 indexed marketId, uint256 indexed amount0, uint256 indexed amount1);
    event LiquidityRemoved(bytes32 indexed marketId, uint128 indexed liquidity);
    event TokensSwapped(
        bytes32 indexed marketId, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );
>>>>>>> origin/main

    constructor(address _uniswapV3Factory, address _swapRouter) {
        magicFactory = IUniswapV3Factory(_uniswapV3Factory);
        swapRouter = ISwapRouter(_swapRouter);
    }

<<<<<<< HEAD
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
        require(marketIdToPool[marketId].pool == address(0), "Pool Already Exists");
=======
    function initializePool(address _tokenA, address _tokenB, uint24 _fee, bytes32 _marketId) external {
        require(_tokenA != _tokenB, "Tokens Must Be Different");
        require(marketPools[_marketId].pool == address(0), "Pool Already Exists");
>>>>>>> origin/main

        //Ensure token order for pool creation.
        if (_tokenA > _tokenB) {
            (_tokenA, _tokenB) = (_tokenB, _tokenA);
        }

        //Create pool.
        address poolAddress = magicFactory.createPool(_tokenA, _tokenB, _fee);
        require(poolAddress != address(0), "Pool Creation Failed");

        // Initialize pool with price = 1 (equal weights for both outcome tokens)
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        uint160 sqrtPriceX96 = 79228162514264337593543950336; // sqrt(1) * 2^96
        pool.initialize(sqrtPriceX96);

        //Update pool data in this contract.
        PoolData memory poolData = PoolData({
            marketId: _marketId,
            pool: poolAddress,
            tokenA: _tokenA,
            tokenB: _tokenB,
            fee: _fee,
            poolInitialized: true
        });

        marketPools[_marketId] = poolData;
        addressToPool[poolAddress] = poolData;
        directPools[_tokenA][_tokenB] = poolAddress;
        directPools[_tokenB][_tokenA] = poolAddress;
        pools.push(poolData); // Add to pools array

        emit PoolInitialized(_marketId, poolAddress, _tokenA, _tokenB, _fee);
    }

<<<<<<< HEAD
    /**
     * @notice Initializes a pool using uniswap v3.
     * @notice Called after generatePool is done.
     * @dev Visibility is public as to aid in testing flow.
     * @param pool Address of the pool.
     * @param sqrtPriceX96 The initial sqrt price of the pool.
     */
    function initializePool(address pool, uint160 sqrtPriceX96) public {
        require(addressToPool[pool].pool == pool, "Pool Does Not Exist");
        require(addressToPool[pool].poolInitialized == false, "Pool Already Initialized");
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
    function mintPosition(address pool, address recipient, int24 tickLower, int24 tickUpper, uint128 amount)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = IUniswapV3PoolActions(pool).mint(recipient, tickLower, tickUpper, amount, "");
    }

    /// @notice Collects tokens owed to a position
    /// @dev Does not recompute fees earned, which must be done either via mint or burn of any amount of liquidity.
    /// Collect must be called by the position owner. To withdraw only token0 or only token1, amount0Requested or
    /// amount1Requested may be set to zero. To withdraw all tokens owed, caller may pass any value greater than the
    /// actual tokens owed, e.g. type(uint128).max. Tokens owed may be from accumulated swap fees or burned liquidity.
    /// @param recipient The address which should receive the fees collected
    /// @param tickLower The lower tick of the position for which to collect fees
    /// @param tickUpper The upper tick of the position for which to collect fees
    /// @param amount0Requested How much token0 should be withdrawn from the fees owed
    /// @param amount1Requested How much token1 should be withdrawn from the fees owed
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    function collect(
        address pool,
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1) {
        (amount0, amount1) =
            IUniswapV3PoolActions(pool).collect(recipient, tickLower, tickUpper, amount0Requested, amount1Requested);
    }

    /// @notice Burn liquidity from the sender and account tokens owed for the liquidity to the position
    /// @dev Can be used to trigger a recalculation of fees owed to a position by calling with an amount of 0
    /// @dev Fees must be collected separately via a call to #collect
    /// @param tickLower The lower tick of the position for which to burn liquidity
    /// @param tickUpper The upper tick of the position for which to burn liquidity
    /// @param amount How much liquidity to burn
    /// @return amount0 The amount of token0 sent to the recipient
    /// @return amount1 The amount of token1 sent to the recipient
    function burn(address pool, int24 tickLower, int24 tickUpper, uint128 amount)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = IUniswapV3PoolActions(pool).burn(tickLower, tickUpper, amount);
    }

    /// @notice Swap token0 for token1, or token1 for token0
    /// @dev The caller of this method receives a callback in the form of IUniswapV3SwapCallback#uniswapV3SwapCallback
    /// @param recipient The address to receive the output of the swap
    /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
    /// @param amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
    /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
    /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
    /// @param data Any data to be passed through to the callback
    /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
    /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
    function swap(
        address pool,
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
        (amount0, amount1) =
            IUniswapV3PoolActions(pool).swap(recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, data);
    }

    /**
     * @notice Returns the pool address for a given pair of tokens and a fee, or address 0 if it does not exist.
     * @dev Calls it straight from uniswap, dosen't use this contract's data.
     * @param tokenA The contract address of either token0 or token1.
     * @param tokenB The contract address of the other token.
     * @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip.
     * @return pool The pool address.
     */
=======
    function addLiquidity(bytes32 _marketId, uint256 _amount0, uint256 _amount1, int24 _tickLower, int24 _tickUpper)
        external
    {
        PoolData storage poolData = marketPools[_marketId];
        require(poolData.poolInitialized, "Pool not active");

        IUniswapV3Pool pool = IUniswapV3Pool(poolData.pool);

        // Transfer tokens from the sender to this contract
        IERC20(poolData.tokenA).transferFrom(msg.sender, address(this), _amount0);
        IERC20(poolData.tokenB).transferFrom(msg.sender, address(this), _amount1);

        // Approve the pool to spend tokens
        IERC20(poolData.tokenA).approve(address(pool), _amount0);
        IERC20(poolData.tokenB).approve(address(pool), _amount1);

        // Get the current sqrt price from the pool
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

        // Calculate the liquidity
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(_tickLower),
            TickMath.getSqrtRatioAtTick(_tickUpper),
            _amount0,
            _amount1
        );

        // Mint liquidity
        pool.mint(msg.sender, _tickLower, _tickUpper, liquidity, abi.encode(msg.sender));

        emit LiquidityAdded(_marketId, _amount0, _amount1);
    }

    function removeLiquidity(bytes32 _marketId, uint128 _liquidity, int24 _tickLower, int24 _tickUpper) external {
        PoolData storage poolData = marketPools[_marketId];
        require(poolData.poolInitialized, "Pool not active");

        IUniswapV3Pool pool = IUniswapV3Pool(poolData.pool);

        pool.burn(_tickLower, _tickUpper, _liquidity);
        pool.collect(msg.sender, _tickLower, _tickUpper, type(uint128).max, type(uint128).max);

        emit LiquidityRemoved(_marketId, _liquidity);
    }

    function swap(bytes32 _marketId, uint256 _amountIn, uint256 _amountOutMinimum, bool _zeroForOne) external {
        PoolData storage poolData = marketPools[_marketId];
        require(poolData.poolInitialized, "Pool not active");

        address inputToken = _zeroForOne ? poolData.tokenA : poolData.tokenB;
        address outputToken = _zeroForOne ? poolData.tokenB : poolData.tokenA;

        // Transfer input tokens to the contract and approve the swap router.
        IERC20(inputToken).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(inputToken).approve(address(swapRouter), _amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: inputToken,
            tokenOut: outputToken,
            fee: poolData.fee,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: _amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        swapRouter.exactInputSingle(params);

        emit TokensSwapped(_marketId, inputToken, outputToken, _amountIn, _amountOutMinimum);
    }

>>>>>>> origin/main
    function getPoolUsingParams(address tokenA, address tokenB, uint24 fee) external view returns (address pool) {
        pool = magicFactory.getPool(tokenA, tokenB, fee);
        return pool;
    }

<<<<<<< HEAD
    /**
     * @notice Returns the pool data for a given marketId, or address 0 if it does not exist.
     * @param marketId The id of the market coming from PredictionMarket.sol.
     * @return pool The struct PoolData for the given marketId.
     */
    function getPoolUsingMarketId(bytes32 marketId) external view returns (PoolData memory pool) {
        pool = marketIdToPool[marketId];
        return pool;
    }

    /**
     * @param poolAddress The address of the pool.
     * @return pool The struct PoolData for the given pool address.
     */
=======
    function getPoolUsingMarketId(bytes32 marketId) external view returns (PoolData memory pool) {
        pool = marketPools[marketId];
        return pool;
    }

>>>>>>> origin/main
    function getPoolUsingAddress(address poolAddress) external view returns (PoolData memory pool) {
        pool = addressToPool[poolAddress];
        return pool;
    }

    function getAllPools() external view returns (PoolData[] memory) {
        return pools;
    }
}
