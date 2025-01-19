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
contract UniswapV3AMMContract is Ownable {
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

    event PoolInitialized(
        bytes32 indexed marketId,
        address indexed pool,
        address tokenA,
        address tokenB,
        uint24 fee
    );

    event LiquidityAdded(
        bytes32 indexed marketId,
        uint256 indexed amount0,
        uint256 indexed amount1
    );
    event LiquidityRemoved(bytes32 indexed marketId, uint128 indexed liquidity);
    event TokensSwapped(
        bytes32 indexed marketId,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event ProtocolFeeCollected(
        address recipient,
        uint256 amountA,
        uint256 amountB
    );
    event FeeCollected(
        address recipient,
        bytes32 indexed marketId,
        uint256 amountA,
        uint256 amountB
    );

    constructor(address _uniswapV3Factory, address _swapRouter) Ownable() {
        magicFactory = IUniswapV3Factory(_uniswapV3Factory);
        swapRouter = ISwapRouter(_swapRouter);
    }

    function initializePool(
        address _tokenA,
        address _tokenB,
        uint24 _fee,
        bytes32 _marketId
    ) external {
        require(_tokenA != _tokenB, "Tokens Must Be Different");
        require(
            marketPools[_marketId].pool == address(0),
            "Pool Already Exists"
        );

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

    function addLiquidity(
        bytes32 _marketId,
        uint256 _amount0,
        uint256 _amount1,
        int24 _tickLower,
        int24 _tickUpper
    ) external {
        PoolData storage poolData = marketPools[_marketId];
        require(poolData.poolInitialized, "Pool not active");

        IUniswapV3Pool pool = IUniswapV3Pool(poolData.pool);

        // Transfer tokens from the sender to this contract
        IERC20(poolData.tokenA).transferFrom(
            msg.sender,
            address(this),
            _amount0
        );
        IERC20(poolData.tokenB).transferFrom(
            msg.sender,
            address(this),
            _amount1
        );

        // Approve the pool to spend tokens
        IERC20(poolData.tokenA).approve(address(pool), _amount0);
        IERC20(poolData.tokenB).approve(address(pool), _amount1);

        // Get the current sqrt price from the pool
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        // Calculate the liquidity
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(_tickLower),
            TickMath.getSqrtRatioAtTick(_tickUpper),
            _amount0,
            _amount1
        );

        // Mint liquidity
        pool.mint(
            msg.sender,
            _tickLower,
            _tickUpper,
            liquidity,
            abi.encode(msg.sender)
        );

        emit LiquidityAdded(_marketId, _amount0, _amount1);
    }

    function removeLiquidity(
        bytes32 _marketId,
        uint128 _liquidity,
        int24 _tickLower,
        int24 _tickUpper
    ) external {
        PoolData storage poolData = marketPools[_marketId];
        require(poolData.poolInitialized, "Pool not active");

        IUniswapV3Pool pool = IUniswapV3Pool(poolData.pool);

        pool.burn(_tickLower, _tickUpper, _liquidity);
        pool.collect(
            msg.sender,
            _tickLower,
            _tickUpper,
            type(uint128).max,
            type(uint128).max
        );

        emit LiquidityRemoved(_marketId, _liquidity);
    }

    function swap(
        bytes32 _marketId,
        uint256 _amountIn,
        uint256 _amountOutMinimum,
        bool _zeroForOne
    ) external {
        PoolData storage poolData = marketPools[_marketId];
        require(poolData.poolInitialized, "Pool not active");

        address inputToken = _zeroForOne ? poolData.tokenA : poolData.tokenB;
        address outputToken = _zeroForOne ? poolData.tokenB : poolData.tokenA;

        // Transfer input tokens to the contract and approve the swap router.
        IERC20(inputToken).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(inputToken).approve(address(swapRouter), _amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
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

        emit TokensSwapped(
            _marketId,
            inputToken,
            outputToken,
            _amountIn,
            _amountOutMinimum
        );
    }

    function collectFee(
        bytes32 marketId,
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1) {
        PoolData memory poolData = marketPools[marketId];
        (amount0, amount1) = IUniswapV3Pool(poolData.pool).collect(
            recipient,
            tickLower,
            tickUpper,
            amount0Requested,
            amount1Requested
        );
        emit FeeCollected(recipient, marketId, amount0, amount1);
    }

    function collectProtocolFee(
        address pool,
        address recipient,
        uint128 tokenA,
        uint128 tokenB
    ) external onlyOwner {
        // Modifications in future, need to figure out how prediction market tokens are valuable to owners.
        IUniswapV3Pool(pool).collectProtocol(recipient, tokenA, tokenB);
        emit ProtocolFeeCollected(pool, tokenA, tokenB);
    }

    function getPoolUsingParams(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool) {
        pool = magicFactory.getPool(tokenA, tokenB, fee);
        return pool;
    }

    function getPoolUsingMarketId(
        bytes32 marketId
    ) external view returns (PoolData memory pool) {
        pool = marketPools[marketId];
        return pool;
    }

    function getPoolUsingAddress(
        address poolAddress
    ) external view returns (PoolData memory pool) {
        pool = addressToPool[poolAddress];
        return pool;
    }

    function getAllPools() external view returns (PoolData[] memory) {
        return pools;
    }
}
