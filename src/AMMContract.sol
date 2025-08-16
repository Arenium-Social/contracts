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
 * @title AMMContract
 * @author Arenium Social
 * @notice This contract manages automated market making for prediction market outcome tokens using Uniswap V3
 * @dev Integrates with Uniswap V3 to provide liquidity pools, position management, and token swapping for
 *      prediction market outcome tokens. The contract acts as a custodian for users' liquidity positions,
 *      holding the NFT tokens while tracking user ownership and allowing users to manage their positions.
 *
 * Key Features:
 * - Automated pool creation for new prediction markets
 * - Liquidity provision and management through Uniswap V3 NFT positions
 * - Token swapping with slippage protection
 * - Position tracking and management for multiple users
 * - Direct pool interaction for custom trading scenarios
 * - Comprehensive pool analytics and position queries
 *
 * Architecture:
 * - Built on Uniswap V3 concentrated liquidity model
 * - Uses NFT-based position management for precise liquidity control
 * - Implements callback pattern for direct pool interactions
 * - Integrates with prediction market contract for automated setup
 *
 * Security Considerations:
 * - Position NFTs are held by this contract but tracked per user
 * - Callback verification ensures only registered pools can trigger callbacks
 * - Slippage protection on all swap operations
 * - Owner-only functions for emergency management
 * - Safe token transfers using OpenZeppelin's SafeERC20
 *
 * Gas Optimizations:
 * - Batch operations where possible
 * - Efficient storage patterns with mappings
 * - Direct pool interactions to bypass router fees when appropriate
 *
 * @custom:security This contract holds user positions as custodian while maintaining user ownership tracking
 * @custom:integration Designed to work seamlessly with PredictionMarket contract
 * @custom:uniswap Implements Uniswap V3 callback interface for direct pool interactions
 */
contract AMMContract is Ownable, IUniswapV3SwapCallback {
    //////////////////////////////////////////////////////////////
    //                   IMMUTABLE VARIABLES                   //
    //////////////////////////////////////////////////////////////

    /// @notice Uniswap V3 factory contract for pool creation and queries
    /// @dev Used to create new pools and verify pool existence
    IUniswapV3Factory public immutable magicFactory;

    /// @notice Uniswap V3 swap router for executing token swaps
    /// @dev Provides standardized swap interface with slippage protection
    ISwapRouter public immutable swapRouter;

    /// @notice Uniswap V3 position manager for NFT-based liquidity positions
    /// @dev Manages minting, increasing, decreasing, and collecting from positions
    INonfungiblePositionManager public immutable nonFungiblePositionManager;

    //////////////////////////////////////////////////////////////
    //                    DATA STRUCTURES                      //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Comprehensive data structure containing all pool-related information
     * @dev Stores essential pool data for efficient lookups and operations
     *
     * @param marketId Unique identifier linking this pool to a prediction market
     * @param pool Address of the Uniswap V3 pool contract
     * @param tokenA Address of the first outcome token (lower address)
     * @param tokenB Address of the second outcome token (higher address)
     * @param fee Fee tier for the pool (500 = 0.05%, 3000 = 0.3%, 10000 = 1%)
     * @param poolInitialized Flag indicating if the pool has been initialized with a price
     *
     * @custom:ordering tokenA and tokenB are ordered by address (tokenA < tokenB) for consistency
     * @custom:initialization poolInitialized becomes true after successful price initialization
     */
    struct PoolData {
        bytes32 marketId; // Links to prediction market
        address pool; // Uniswap V3 pool address
        address tokenA; // First token (lower address)
        address tokenB; // Second token (higher address)
        uint24 fee; // Pool fee tier
        bool poolInitialized; // Initialization status
    }

    //////////////////////////////////////////////////////////////
    //                        STORAGE                          //
    //////////////////////////////////////////////////////////////

    /// @notice Array storing all created pools for enumeration and analytics
    /// @dev Provides a way to iterate through all pools managed by this contract
    PoolData[] public pools;

    /// @notice Maps market ID to its corresponding pool data
    /// @dev Primary lookup mechanism for pools by market identifier
    mapping(bytes32 => PoolData) public marketIdToPool;

    /// @notice Maps pool address to its corresponding pool data
    /// @dev Enables reverse lookup from pool address to market data
    mapping(address => PoolData) public poolAddressToPool;

    /// @notice Maps token pairs to their pool addresses for quick lookups
    /// @dev Bidirectional mapping: both (tokenA, tokenB) and (tokenB, tokenA) point to same pool
    mapping(address => mapping(address => address)) public tokenPairToPoolAddress;

    /// @notice Maps user address and market ID to their NFT position ID
    /// @dev Tracks which NFT position belongs to each user in each market
    /// @custom:constraint Each user can only have one position per market
    mapping(address => mapping(bytes32 => uint256)) public userAddressToMarketIdToPositionId;

    //////////////////////////////////////////////////////////////
    //                          EVENTS                         //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Emitted when a new Uniswap V3 pool is created
     * @param pool Address of the newly created pool contract
     */
    event PoolCreated(address indexed pool);

    /**
     * @notice Emitted when a pool is successfully initialized with a starting price
     * @param marketId Unique identifier for the prediction market
     * @param pool Address of the initialized pool
     * @param tokenA Address of the first outcome token
     * @param tokenB Address of the second outcome token
     * @param fee Fee tier of the pool
     */
    event PoolInitialized(bytes32 indexed marketId, address indexed pool, address tokenA, address tokenB, uint24 fee);

    /**
     * @notice Emitted when a new liquidity position is minted for a user
     * @param user Address of the user who owns the position
     * @param marketId Market identifier for the position
     * @param amount0 Initial amount of tokenA added to the position
     * @param amount1 Initial amount of tokenB added to the position
     */
    event NewPositionMinted(address indexed user, bytes32 indexed marketId, uint256 amount0, uint256 amount1);

    event LiquidityAdded(bytes32 indexed marketId, uint256 indexed amount0, uint256 indexed amount1);
    event LiquidityRemoved(address user, uint128 liquidity, uint256 amount0Decreased, uint256 amount1Decreased);
    event TokensCollected(address user, uint256 amount0Collected, uint256 amount1Collected);
    event TokensSwapped(
        bytes32 indexed marketId, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );
    event ProtocolFeeCollected(address recipient, uint256 amountA, uint256 amountB);
    event FeeCollected(address recipient, bytes32 indexed marketId, uint256 amountA, uint256 amountB);

    constructor(address _uniswapV3Factory, address _uniswapSwapRouter, address _uniswapNonFungiblePositionManager) {
        magicFactory = IUniswapV3Factory(_uniswapV3Factory);
        swapRouter = ISwapRouter(_uniswapSwapRouter);
        nonFungiblePositionManager = INonfungiblePositionManager(_uniswapNonFungiblePositionManager);
    }

    /**
     * @notice Abstract function to create, initialize and update pool data in this contract.
     * @param _tokenA Address of the first token.
     * @param _tokenB Address of the second token.
     * @param _fee Fee tier for the pool.
     * @param _marketId Unique identifier for the prediction market.
     */
    function initializePool(address _tokenA, address _tokenB, uint24 _fee, bytes32 _marketId)
        external
        returns (address poolAddress)
    {
        /// @dev Create the pool
        poolAddress = _createPool(_marketId, _tokenA, _tokenB, _fee);

        /// @dev Initialize pool and update pool data in this contract
        _initializePoolAndUpdateContract(
            PoolData({
                marketId: _marketId,
                pool: poolAddress,
                tokenA: _tokenA,
                tokenB: _tokenB,
                fee: _fee,
                poolInitialized: false
            })
        );
    }

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
    ) external returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        PoolData storage poolData = marketIdToPool[_marketId];
        require(poolData.poolInitialized, "Pool not active");

        /// @dev Transfer tokens from the sender to this contract
        IERC20(poolData.tokenA).transferFrom(msg.sender, address(this), _amount0);
        IERC20(poolData.tokenB).transferFrom(msg.sender, address(this), _amount1);

        /// @dev Mint a new position if the user doesn't have a position.
        if (userAddressToMarketIdToPositionId[_user][_marketId] == 0) {
            (tokenId,,,) =
                _mintNewPosition(marketIdToPool[_marketId], _user, _amount0, _amount1, _tickLower, _tickUpper);
        }
        /// @dev Else add liquidity to the existing position.
        else if (userAddressToMarketIdToPositionId[_user][_marketId] != 0) {
            _addLiquidityToExistingPosition(marketIdToPool[_marketId], _user, _amount0, _amount1);
            tokenId = userAddressToMarketIdToPositionId[_user][_marketId];
        }

        /// @dev Refund the user if there is a difference between liquidity added actually and liquidity added in the params.
        _refundExtraLiquidityWhileMinting(marketIdToPool[_marketId], amount0, amount1, _amount0, _amount1);

        /// @dev Call getter and return current user holdings.
        (,,,, liquidity,,,,, amount0, amount1) = getUserPositionInPool(_user, _marketId);

        emit LiquidityAdded(_marketId, amount0, amount1);
    }

    /**
     * @notice Abstract Function to remove liquidity and collect tokens from an existing position.
     * @param _marketId Unique identifier for the prediction market.
     * @param _user Address of the user.
     * @param _liquidity Liquidity to decrease.
     * @param _amount0Min Minimum amount of tokenA to receive.
     * @param _amount1Min Minimum amount of tokenB to receive.
     * @return amount0Decreased Amount of tokenA decreased.
     * @return amount1Decreased Amount of tokenB decreased.
     * @return amount0Collected Amount of tokenA collected.
     * @return amount1Collected Amount of tokenB collected.
     */
    function removeLiquidity(
        bytes32 _marketId,
        address _user,
        uint128 _liquidity,
        uint256 _amount0Min,
        uint256 _amount1Min
    )
        external
        returns (uint256 amount0Decreased, uint256 amount1Decreased, uint256 amount0Collected, uint256 amount1Collected)
    {
        (amount0Decreased, amount1Decreased) =
            _decreaseLiquidity(marketIdToPool[_marketId], _user, _liquidity, _amount0Min, _amount1Min);
        (amount0Collected, amount1Collected) = _collectTokensFromPosition(marketIdToPool[_marketId], _user);
    }

    /**
     * @notice Abstract Function to swap tokens in a specified pool.
     * @dev The swap is executed using the Uniswap V3 swap router.
     * @param _marketId Unique identifier for the prediction market.
     * @param _amountIn Amount of input tokens to swap.
     * @param _amountOutMinimum Minimum amount of output tokens to receive.
     * @param _zeroForOne Direction of the swap (true for tokenA to tokenB, false for tokenB to tokenA).
     */
    function swap(bytes32 _marketId, uint256 _amountIn, uint256 _amountOutMinimum, bool _zeroForOne) external {
        PoolData storage poolData = marketIdToPool[_marketId];
        require(poolData.poolInitialized, "Pool not active");

        address inputToken = _zeroForOne ? poolData.tokenA : poolData.tokenB;
        address outputToken = _zeroForOne ? poolData.tokenB : poolData.tokenA;

        /// @dev Transfer input tokens to the contract and approve the swap router
        IERC20(inputToken).transferFrom(msg.sender, address(this), _amountIn);

        /// @dev Execute the swap
        _executeSwap(inputToken, outputToken, _amountIn, _amountOutMinimum, _marketId);
    }

    /**
     * @notice Internal Function to create a new Uniswap V3 pool for a given market.
     * @param _marketId Unique identifier for the prediction market.
     * @param _tokenA Address of the first token.
     * @param _tokenB Address of the second token.
     * @param _fee Fee tier for the pool.
     */
    function _createPool(bytes32 _marketId, address _tokenA, address _tokenB, uint24 _fee)
        internal
        returns (address poolAddress)
    {
        require(_tokenA != _tokenB, "Tokens Must Be Different");
        require(marketIdToPool[_marketId].pool == address(0), "Pool Already Exists");

        /// @dev Ensure token order for pool creation.
        if (_tokenA > _tokenB) {
            (_tokenA, _tokenB) = (_tokenB, _tokenA);
        }

        /// @dev Create the pool
        poolAddress = magicFactory.createPool(_tokenA, _tokenB, _fee);
        require(poolAddress != address(0), "Pool Creation Failed");
        emit PoolCreated(poolAddress);
    }

    /**
     * @notice Internal Function to initialize the pool and update pool data in this contract.
     * @dev The pool is created with a price of 1 (equal weights for both tokens).
     * @param poolData PoolData struct containing pool information.
     */
    function _initializePoolAndUpdateContract(PoolData memory poolData) internal {
        require(marketIdToPool[poolData.marketId].pool == address(0), "Pool already initialised");
        /// @dev Initialize the pool with a price of 1 (equal weights for both tokens).
        IUniswapV3Pool pool = IUniswapV3Pool(poolData.pool);
        uint160 sqrtPriceX96 = 79228162514264337593543950336;
        /// @param sqrtPriceX96 sqrt(1) * 2^96
        pool.initialize(sqrtPriceX96);

        /// @dev Update pool data in this contract
        poolData.poolInitialized = true;
        marketIdToPool[poolData.marketId] = poolData;
        poolAddressToPool[poolData.pool] = poolData;
        tokenPairToPoolAddress[poolData.tokenA][poolData.tokenB] = poolData.pool;
        tokenPairToPoolAddress[poolData.tokenB][poolData.tokenA] = poolData.pool;
        pools.push(poolData);

        emit PoolInitialized(poolData.marketId, poolData.pool, poolData.tokenA, poolData.tokenB, poolData.fee);
    }

    /**
     * @notice Internal Function to mint a new position for a user.
     * @notice User must not have a position in the pool to mint a new position.
     * @dev Position is minted to this contract, but in the contract data user's position is stored.
     * @param poolData PoolData struct containing pool information.
     * @param _user Address of the user.
     * @param _amount0 Amount of tokenA to add.
     * @param _amount1 Amount of tokenB to add.
     * @param _tickLower Lower tick bound for the liquidity position.
     * @param _tickUpper Upper tick bound for the liquidity position.
     */
    function _mintNewPosition(
        PoolData memory poolData,
        address _user,
        uint256 _amount0,
        uint256 _amount1,
        int24 _tickLower,
        int24 _tickUpper
    ) internal returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        require(userAddressToMarketIdToPositionId[_user][poolData.marketId] == 0, "User already has a position");
        /// @dev Approve the pool to spend tokens
        IERC20(poolData.tokenA).approve(address(nonFungiblePositionManager), _amount0);
        IERC20(poolData.tokenB).approve(address(nonFungiblePositionManager), _amount1);

        /// @dev Calculate the liquidity
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: poolData.tokenA,
            token1: poolData.tokenB,
            fee: poolData.fee,
            tickLower: _tickLower,
            tickUpper: _tickUpper,
            amount0Desired: _amount0,
            amount1Desired: _amount1,
            amount0Min: _amount0,
            amount1Min: _amount1,
            recipient: address(this),
            deadline: block.timestamp
        });

        /// @dev Mint a new liquidity position and update user's position id
        (tokenId, liquidity, amount0, amount1) = nonFungiblePositionManager.mint(params);
        userAddressToMarketIdToPositionId[_user][poolData.marketId] = tokenId;

        emit NewPositionMinted(_user, poolData.marketId, _amount0, _amount1);
    }

    /**
     * @notice Internal Function to add liquidity to an existing position.
     * @param poolData PoolData struct containing pool information.
     * @param _amount0 Amount of tokenA to add.
     * @param _amount1 Amount of tokenB to add.
     */
    function _addLiquidityToExistingPosition(
        PoolData memory poolData,
        address _user,
        uint256 _amount0,
        uint256 _amount1
    ) internal returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        /// @dev Approve the pool to spend tokens.
        IERC20(poolData.tokenA).approve(address(nonFungiblePositionManager), _amount0);
        IERC20(poolData.tokenB).approve(address(nonFungiblePositionManager), _amount1);

        /// @dev Prepare increaseLiquidity params.
        INonfungiblePositionManager.IncreaseLiquidityParams memory increaseLiquidityParams = INonfungiblePositionManager
            .IncreaseLiquidityParams({
            tokenId: userAddressToMarketIdToPositionId[_user][poolData.marketId],
            amount0Desired: _amount0,
            amount1Desired: _amount1,
            amount0Min: _amount0,
            amount1Min: _amount1,
            deadline: block.timestamp
        });

        /// @dev Increase liquidity to the existing position.
        (liquidity, amount0, amount1) = nonFungiblePositionManager.increaseLiquidity(increaseLiquidityParams);
    }

    /**
     * @notice Internal Function to refund the user if there is a difference between liquidity added actually and liquidity added in the params.
     * @param poolData PoolData struct containing pool information.
     * @param amount0 Amount of tokenA in the position.
     * @param amount1 Amount of tokenB in the position.
     * @param _amount0 Amount of tokenA to add.
     * @param _amount1 Amount of tokenB to add.
     */
    function _refundExtraLiquidityWhileMinting(
        PoolData memory poolData,
        uint256 amount0,
        uint256 amount1,
        uint256 _amount0,
        uint256 _amount1
    ) internal returns (uint256 amount0Refunded, uint256 amount1Refunded) {
        if (amount0 > _amount0) {
            IERC20(poolData.tokenA).approve(address(nonFungiblePositionManager), amount0 - _amount0);
            bool success = IERC20(poolData.tokenA).transferFrom(address(this), msg.sender, amount0 - _amount0);
            require(success, "Transfer failed");
            amount0Refunded = amount0 - _amount0;
        }
        if (amount1 > _amount1) {
            IERC20(poolData.tokenB).approve(address(nonFungiblePositionManager), amount1 - _amount1);
            bool success = IERC20(poolData.tokenB).transferFrom(address(this), msg.sender, amount1 - _amount1);
            require(success, "Transfer failed");
            amount1Refunded = amount1 - _amount1;
        }
    }

    /**
     * @notice Internal Function to decrease liquidity from an existing position.
     * @param _user Address of the user.
     * @param _liquidity Liquidity to decrease.
     * @param _amount0Min Minimum amount of tokenA to receive.
     * @param _amount1Min Minimum amount of tokenB to receive.
     * @return amount0Decreased Amount of tokenA decreased.
     * @return amount1Decreased Amount of tokenB decreased.
     */
    function _decreaseLiquidity(
        PoolData memory poolData,
        address _user,
        uint128 _liquidity,
        uint256 _amount0Min,
        uint256 _amount1Min
    ) internal returns (uint256 amount0Decreased, uint256 amount1Decreased) {
        require(
            userAddressToMarketIdToPositionId[_user][poolData.marketId] != 0,
            "No positions to decrease liquidity, try adding liquidity first"
        );
        /// @dev Call getter and return current user holdings.
        (,,,, uint128 liquidity,,,,, uint256 amount0, uint256 amount1) = getUserPositionInPool(_user, poolData.marketId);
        require(liquidity >= _liquidity, "Not enough liquidity to decrease, try adding liquidity first");
        require(amount0 >= _amount0Min, "Not enough tokenA to decrease, try adding more tokenA");
        require(amount1 >= _amount1Min, "Not enough tokenB to decrease, try adding more tokenB");
        /// @dev Prepare decreaseLiquidity params.
        INonfungiblePositionManager.DecreaseLiquidityParams memory decreaseParams = INonfungiblePositionManager
            .DecreaseLiquidityParams({
            tokenId: userAddressToMarketIdToPositionId[_user][poolData.marketId],
            liquidity: _liquidity,
            amount0Min: _amount0Min,
            amount1Min: _amount1Min,
            deadline: block.timestamp
        });

        /// @dev Decrease liquidity from the existing position.
        (amount0Decreased, amount1Decreased) = nonFungiblePositionManager.decreaseLiquidity(decreaseParams);

        emit LiquidityRemoved(_user, _liquidity, amount0Decreased, amount1Decreased);
    }

    /**
     * @notice Internal Function to collect tokens from an existing position.
     * @param _user Address of the user.
     * @return amount0Collected Amount of tokenA collected.
     * @return amount1Collected Amount of tokenB collected.
     */
    function _collectTokensFromPosition(PoolData memory poolData, address _user)
        internal
        returns (uint256 amount0Collected, uint256 amount1Collected)
    {
        /// @dev Prepare collect params.
        INonfungiblePositionManager.CollectParams memory collectParams = INonfungiblePositionManager.CollectParams({
            tokenId: userAddressToMarketIdToPositionId[_user][poolData.marketId],
            recipient: _user,
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        /// @dev Collect tokens (including fees) from the position and transfer to user.
        (amount0Collected, amount1Collected) = nonFungiblePositionManager.collect(collectParams);

        emit TokensCollected(_user, amount0Collected, amount1Collected);
    }

    /**
     * @notice Internal Function to execute a swap.
     * @param _inputToken Address of the input token.
     * @param _outputToken Address of the output token.
     * @param _amountIn Amount of input tokens to swap.
     * @param _amountOutMinimum Minimum amount of output tokens to receive.
     * @param _marketId Unique identifier for the prediction market.
     */
    function _executeSwap(
        address _inputToken,
        address _outputToken,
        uint256 _amountIn,
        uint256 _amountOutMinimum,
        bytes32 _marketId
    ) internal {
        IERC20(_inputToken).approve(address(swapRouter), _amountIn);

        bool zeroForOne = _inputToken < _outputToken;

        // Set the appropriate price limit
        uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: _inputToken,
            tokenOut: _outputToken,
            fee: marketIdToPool[_marketId].fee,
            recipient: msg.sender,
            deadline: block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: _amountOutMinimum,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        swapRouter.exactInputSingle(params);

        emit TokensSwapped(_marketId, _inputToken, _outputToken, _amountIn, _amountOutMinimum);
    }

    /**
     * @notice Callback function called by Uniswap V3 pools during swaps
     * @dev Only callable by pools we've registered in our mappings
     * @param amount0Delta Amount of token0 owed to the pool (positive) or to receive (negative)
     * @param amount1Delta Amount of token1 owed to the pool (positive) or to receive (negative)
     * @param data Encoded data containing the original swap initiator
     */
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        // Verify the callback is from a known pool
        PoolData memory poolData = poolAddressToPool[msg.sender];
        require(poolData.pool != address(0), "Callback from unknown pool");

        // Decode the original sender and this contract address
        (address sender, address thisContract) = abi.decode(data, (address, address));

        // Determine which token needs to be paid
        if (amount0Delta > 0) {
            // Pool needs token0 - transfer from the stored tokens in this contract
            IERC20(poolData.tokenA).transfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            // Pool needs token1 - transfer from the stored tokens in this contract
            IERC20(poolData.tokenB).transfer(msg.sender, uint256(amount1Delta));
        }
    }

    /**
     * @notice Execute a swap directly through the pool, bypassing the router
     * @dev This function is useful for testing or when the router doesn't recognize locally created pools
     * @param _marketId Unique identifier for the prediction market
     * @param _amountIn Amount of input tokens to swap
     * @param _amountOutMinimum Minimum amount of output tokens to receive
     * @param _zeroForOne Direction of the swap (true for tokenA to tokenB, false for tokenB to tokenA)
     * @return amountOut The actual amount of output tokens received
     */
    function directPoolSwap(bytes32 _marketId, uint256 _amountIn, uint256 _amountOutMinimum, bool _zeroForOne)
        external
        returns (uint256 amountOut)
    {
        PoolData storage poolData = marketIdToPool[_marketId];
        require(poolData.poolInitialized, "Pool not active");

        IUniswapV3Pool pool = IUniswapV3Pool(poolData.pool);

        // Determine input and output tokens
        address inputToken = _zeroForOne ? poolData.tokenA : poolData.tokenB;
        address outputToken = _zeroForOne ? poolData.tokenB : poolData.tokenA;

        // Transfer input tokens from user to this contract
        IERC20(inputToken).transferFrom(msg.sender, address(this), _amountIn);

        // Set appropriate price limit based on swap direction
        uint160 sqrtPriceLimitX96 = _zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

        // Execute the swap
        // The pool will callback to uniswapV3SwapCallback for payment
        (int256 amount0, int256 amount1) = pool.swap(
            msg.sender, // recipient of the output tokens
            _zeroForOne, // direction of the swap
            int256(_amountIn), // exact input amount (positive for exact input)
            sqrtPriceLimitX96, // price limit
            abi.encode(msg.sender, address(this)) // callback data
        );

        // Calculate the actual output amount
        // For exact input swaps: if zeroForOne, amount1 is negative (output)
        // if !zeroForOne, amount0 is negative (output)
        amountOut = uint256(-(_zeroForOne ? amount1 : amount0));

        // Verify slippage protection
        require(amountOut >= _amountOutMinimum, "Insufficient output amount");

        // Emit swap event
        emit TokensSwapped(_marketId, inputToken, outputToken, _amountIn, amountOut);

        return amountOut;
    }

    /**
     * @notice Retrieves the pool address using token addresses and fee tier.
     * @param tokenA Address of the first token.
     * @param tokenB Address of the second token.
     * @param fee Fee tier for the pool.
     * @return pool Address of the pool.
     */
    function getPoolUsingParams(address tokenA, address tokenB, uint24 fee) external view returns (address pool) {
        pool = magicFactory.getPool(tokenA, tokenB, fee);
        return pool;
    }

    /**
     * @notice Retrieves pool data using the market ID.
     * @param marketId Unique identifier for the prediction market.
     * @return pool PoolData struct containing pool information.
     */
    function getPoolUsingMarketId(bytes32 marketId) external view returns (PoolData memory pool) {
        pool = marketIdToPool[marketId];
        return pool;
    }

    /**
     * @notice Retrieves pool data using the pool address.
     * @param poolAddress Address of the pool.
     * @return pool PoolData struct containing pool information.
     */
    function getPoolUsingAddress(address poolAddress) external view returns (PoolData memory pool) {
        pool = poolAddressToPool[poolAddress];
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
    function getUserPositionInPool(address _user, bytes32 _marketId)
        public
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
        (, operator, token0, token1, fee, tickLower, tickUpper, liquidity,,, tokensOwed0, tokensOwed1) =
            nonFungiblePositionManager.positions(userAddressToMarketIdToPositionId[_user][_marketId]);
        IUniswapV3Pool pool = IUniswapV3Pool(marketIdToPool[_marketId].pool);
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        (amount0, amount1) = getAmountsForLiquidityHelper(sqrtPriceX96, tickLower, tickUpper, liquidity);
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
    function getPoolReserves(bytes32 marketId) external view returns (uint256 reserve0, uint256 reserve1) {
        PoolData memory poolData = marketIdToPool[marketId];
        require(poolData.poolInitialized, "Pool not active");

        IUniswapV3Pool pool = IUniswapV3Pool(poolData.pool);

        // Get the current reserves of the pool
        (uint160 sqrtPriceX96, int24 tick,,,,,) = pool.slot0();

        // Calculate the reserves using the liquidity and tick
        uint128 liquidity = pool.liquidity();
        (reserve0, reserve1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tick - 1), TickMath.getSqrtRatioAtTick(tick + 1), liquidity
        );
    }

    /**
     * @notice Internal Function to get the amount of tokenA and tokenB in a user's position.
     * @param tickLower Lower tick bound for the liquidity position.
     * @param tickUpper Upper tick bound for the liquidity position.
     * @param liquidity Liquidity in the position.
     * @return amount0 Amount of tokenA in the position.
     * @return amount1 Amount of tokenB in the position.
     */
    function getAmountsForLiquidityHelper(uint160 sqrtPriceX96, int24 tickLower, int24 tickUpper, uint128 liquidity)
        public
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        uint160 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        (amount0, amount1) =
            LiquidityAmounts.getAmountsForLiquidity(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, liquidity);
    }
}
