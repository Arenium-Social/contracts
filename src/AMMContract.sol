// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3SwapCallback} from "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {ExpandedERC20, ExpandedIERC20} from "@uma/core/contracts/common/implementation/ExpandedERC20.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {LiquidityAmounts} from "./lib/LiquidityAmounts.sol";
import {TickMath} from "./lib/TickMath.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";

/**
 * @title UniswapV3AMMContract
 * @author Arenium Social
 * @notice This contract manages the trading of outcome tokens from a prediction market using Uniswap V3 liquidity pools.
 * @dev The creation of pools is automated when a new market is initialized in the prediction market.
 */
contract AMMContract is Ownable {
    // Immutable Uniswap V3 factory and swap router addresses
    IUniswapV3Factory public immutable magicFactory;
    ISwapRouter public immutable swapRouter;
    INonfungiblePositionManager public immutable nonFungiblePositionManager;

    // Struct to store pool-related data
    struct PoolData {
        bytes32 marketId; // Unique identifier for the prediction market
        address pool; // Address of the Uniswap V3 pool
        address tokenA; // Address of the first token in the pool
        address tokenB; // Address of the second token in the pool
        uint24 fee; // Fee tier for the pool
        bool poolInitialized; // Flag to check if the pool is initialized
    }

    // Array to store all pools
    PoolData[] public pools;

    // Mappings to store pool data for quick access
    mapping(bytes32 => PoolData) public marketPools; // Maps marketId to PoolData
    mapping(address => PoolData) public addressToPool; // Maps pool address to PoolData
    mapping(address => mapping(address => address)) public directPools; // Maps token pairs to pool addresses
    mapping(address => uint256) public userPositionIds; // Maps user address to their position token id

    // Events
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

    /**
     * @notice Constructor to initialize the contract with Uniswap V3 factory and swap router addresses.
     * @param _uniswapV3Factory Address of the Uniswap V3 factory.
     * @param _swapRouter Address of the Uniswap V3 swap router.
     */
    constructor(
        address _uniswapV3Factory,
        address _swapRouter,
        address _uniswapNonFungiblePositionManager
    ) {
        magicFactory = IUniswapV3Factory(_uniswapV3Factory);
        swapRouter = ISwapRouter(_swapRouter);
        nonFungiblePositionManager = INonfungiblePositionManager(
            _uniswapNonFungiblePositionManager
        );
    }

    /**
     * @notice Initializes a new Uniswap V3 pool for a given market.
     * @dev The pool is created with a price of 1 (equal weights for both tokens).
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
    ) external {
        require(_tokenA != _tokenB, "Tokens Must Be Different");
        require(
            marketPools[_marketId].pool == address(0),
            "Pool Already Exists"
        );

        // Ensure token order for pool creation
        if (_tokenA > _tokenB) {
            (_tokenA, _tokenB) = (_tokenB, _tokenA);
        }

        // Create the pool
        address poolAddress = magicFactory.createPool(_tokenA, _tokenB, _fee);
        require(poolAddress != address(0), "Pool Creation Failed");

        // Initialize the pool with a price of 1 (equal weights for both tokens)
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        uint160 sqrtPriceX96 = 79228162514264337593543950336; // sqrt(1) * 2^96
        // uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(0);
        pool.initialize(sqrtPriceX96);

        // Update pool data in this contract
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

    /**
     * @notice Adds liquidity to a specified pool.
     * @dev The liquidity is added within the specified tick range.
     * @param _marketId Unique identifier for the prediction market.
     * @param _amount0 Amount of tokenA to add.
     * @param _amount1 Amount of tokenB to add.
     * @param _tickLower Lower tick bound for the liquidity position.
     * @param _tickUpper Upper tick bound for the liquidity position.
     */
    function addLiquidity(
        bytes32 _marketId,
        uint256 _amount0,
        uint256 _amount1,
        int24 _tickLower,
        int24 _tickUpper
    )
        public
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
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
        IERC20(poolData.tokenA).approve(
            address(nonFungiblePositionManager),
            _amount0
        );
        IERC20(poolData.tokenB).approve(
            address(nonFungiblePositionManager),
            _amount1
        );

        // Get the current sqrt price from the pool
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        // Calculate the liquidity
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: poolData.tokenA,
                token1: poolData.tokenB,
                fee: poolData.fee,
                tickLower: _tickLower,
                tickUpper: _tickUpper,
                amount0Desired: _amount0,
                amount1Desired: _amount1,
                amount0Min: _amount0,
                amount1Min: _amount1,
                recipient: msg.sender,
                deadline: block.timestamp
            });

        // Mint liquidity
        (tokenId, liquidity, amount0, amount1) = nonFungiblePositionManager
            .mint(params);
        userPositionIds[msg.sender] = tokenId;

        emit LiquidityAdded(_marketId, _amount0, _amount1);
    }

    /**
     * @notice Removes liquidity from a specified pool.
     * @dev The liquidity is removed from the specified position, and the tokens are collected and sent to the caller.
     * @param _marketId Unique identifier for the prediction market.
     * @param _tokenId The NFT token ID representing the liquidity position.
     * @param _liquidity Amount of liquidity to remove.
     * @param _amount0Min Minimum amount of token0 to receive.
     * @param _amount1Min Minimum amount of token1 to receive.
     */
    function removeLiquidity(
        bytes32 _marketId,
        uint256 _tokenId,
        uint128 _liquidity,
        uint256 _amount0Min,
        uint256 _amount1Min
    )
        external
        returns (
            address wtf,
            uint256 amount0Decreased,
            uint256 amount1Decreased,
            uint256 amount0Collected,
            uint256 amount1Collected
        )
    {
        // Ensure the caller owns the NFT position
        require(
            IERC721(address(nonFungiblePositionManager)).ownerOf(_tokenId) ==
                msg.sender,
            "Not the owner of the position"
        );

        // Decrease liquidity
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory decreaseParams = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: _tokenId,
                    liquidity: _liquidity,
                    amount0Min: _amount0Min,
                    amount1Min: _amount1Min,
                    deadline: block.timestamp
                });

        (amount0Decreased, amount1Decreased) = nonFungiblePositionManager
            .decreaseLiquidity(decreaseParams);

        // Collect tokens (including fees)
        INonfungiblePositionManager.CollectParams
            memory collectParams = INonfungiblePositionManager.CollectParams({
                tokenId: _tokenId,
                recipient: msg.sender,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0Collected, amount1Collected) = nonFungiblePositionManager
            .collect(collectParams);
        wtf = msg.sender;
        emit LiquidityRemoved(_marketId, _liquidity);
    }

    /**
     * @notice Swaps tokens in a specified pool.
     * @dev The swap is executed using the Uniswap V3 swap router.
     * @param _marketId Unique identifier for the prediction market.
     * @param _amountIn Amount of input tokens to swap.
     * @param _amountOutMinimum Minimum amount of output tokens to receive.
     * @param _zeroForOne Direction of the swap (true for tokenA to tokenB, false for tokenB to tokenA).
     */
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

        // Transfer input tokens to the contract and approve the swap router
        IERC20(inputToken).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(inputToken).approve(address(swapRouter), _amountIn);

        // Execute the swap
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

    /**
     * @notice Collects fees from a specified liquidity position.
     * @param marketId Unique identifier for the prediction market.
     * @param recipient Address to receive the collected fees.
     * @param tickLower Lower tick bound for the liquidity position.
     * @param tickUpper Upper tick bound for the liquidity position.
     * @param amount0Requested Amount of tokenA fees to collect.
     * @param amount1Requested Amount of tokenB fees to collect.
     * @return amount0 Amount of tokenA fees collected.
     * @return amount1 Amount of tokenB fees collected.
     */
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

    /**
     * @notice Collects protocol fees from a specified pool.
     * @dev Only callable by the contract owner.
     * @param pool Address of the pool.
     * @param recipient Address to receive the collected fees.
     * @param tokenA Amount of tokenA fees to collect.
     * @param tokenB Amount of tokenB fees to collect.
     */
    function collectProtocolFee(
        address pool,
        address recipient,
        uint128 tokenA,
        uint128 tokenB
    ) external onlyOwner {
        IUniswapV3Pool(pool).collectProtocol(recipient, tokenA, tokenB);
        emit ProtocolFeeCollected(pool, tokenA, tokenB);
    }

    /**
     * @notice Retrieves the pool address using token addresses and fee tier.
     * @param tokenA Address of the first token.
     * @param tokenB Address of the second token.
     * @param fee Fee tier for the pool.
     * @return pool Address of the pool.
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
     * @notice Retrieves pool data using the market ID.
     * @param marketId Unique identifier for the prediction market.
     * @return pool PoolData struct containing pool information.
     */
    function getPoolUsingMarketId(
        bytes32 marketId
    ) external view returns (PoolData memory pool) {
        pool = marketPools[marketId];
        return pool;
    }

    /**
     * @notice Retrieves pool data using the pool address.
     * @param poolAddress Address of the pool.
     * @return pool PoolData struct containing pool information.
     */
    function getPoolUsingAddress(
        address poolAddress
    ) external view returns (PoolData memory pool) {
        pool = addressToPool[poolAddress];
        return pool;
    }

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
        address _user
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
        )
    {
        (
            ,
            operator,
            token0,
            token1,
            fee,
            tickLower,
            tickUpper,
            liquidity,
            ,
            ,
            tokensOwed0,
            tokensOwed1
        ) = nonFungiblePositionManager.positions(userPositionIds[_user]);
        (amount0, amount1) = getAmountsForLiquidityHelper(
            fee,
            tickLower,
            tickUpper,
            liquidity
        );
    }

    /**
     * @notice Retrieves all pools stored in the contract.
     * @return Array of PoolData structs.
     */
    function getAllPools() external view returns (PoolData[] memory) {
        return pools;
    }

    /**
     * @notice Retrieves the reserves of both tokens in a specified pool.
     * @param marketId Unique identifier for the prediction market.
     * @return reserve0 Amount of tokenA in the pool.
     * @return reserve1 Amount of tokenB in the pool.
     */
    function getPoolReserves(
        bytes32 marketId
    ) external view returns (uint256 reserve0, uint256 reserve1) {
        PoolData memory poolData = marketPools[marketId];
        require(poolData.poolInitialized, "Pool not active");

        IUniswapV3Pool pool = IUniswapV3Pool(poolData.pool);

        // Get the current reserves of the pool
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = pool.slot0();

        // Calculate the reserves using the liquidity and tick
        uint128 liquidity = pool.liquidity();
        (reserve0, reserve1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tick - 1),
            TickMath.getSqrtRatioAtTick(tick + 1),
            liquidity
        );
    }

    function getAmountsForLiquidityHelper(
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public pure returns (uint256 amount0, uint256 amount1) {
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(int24(fee));
        uint160 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            sqrtPriceAX96,
            sqrtPriceBX96,
            liquidity
        );
    }
}
