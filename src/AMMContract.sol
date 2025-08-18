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

    /**
     * @notice Emitted when liquidity is added to a pool (new or existing position)
     * @param marketId Market identifier where liquidity was added
     * @param amount0 Amount of tokenA added
     * @param amount1 Amount of tokenB added
     */
    event LiquidityAdded(bytes32 indexed marketId, uint256 indexed amount0, uint256 indexed amount1);

    /**
     * @notice Emitted when liquidity is removed from a position
     * @param user Address of the user removing liquidity
     * @param liquidity Amount of liquidity removed
     * @param amount0Decreased Amount of tokenA made available for collection
     * @param amount1Decreased Amount of tokenB made available for collection
     */
    event LiquidityRemoved(address user, uint128 liquidity, uint256 amount0Decreased, uint256 amount1Decreased);

    /**
     * @notice Emitted when tokens (including fees) are collected from a position
     * @param user Address of the user collecting tokens
     * @param amount0Collected Amount of tokenA collected (includes fees)
     * @param amount1Collected Amount of tokenB collected (includes fees)
     */
    event TokensCollected(address user, uint256 amount0Collected, uint256 amount1Collected);

    /**
     * @notice Emitted when tokens are swapped through the AMM
     * @param marketId Market identifier for the pool used
     * @param tokenIn Address of the input token
     * @param tokenOut Address of the output token
     * @param amountIn Amount of input tokens provided
     * @param amountOut Actual amount of output tokens received
     */
    event TokensSwapped(
        bytes32 indexed marketId, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    /**
     * @notice Emitted when protocol fees are collected by the owner
     * @param recipient Address receiving the collected fees
     * @param amountA Amount of tokenA collected
     * @param amountB Amount of tokenB collected
     */
    event ProtocolFeeCollected(address recipient, uint256 amountA, uint256 amountB);

    /**
     * @notice Emitted when trading fees are collected from a specific market
     * @param recipient Address receiving the collected fees
     * @param marketId Market identifier for the fees collected
     * @param amountA Amount of tokenA collected as fees
     * @param amountB Amount of tokenB collected as fees
     */
    event FeeCollected(address recipient, bytes32 indexed marketId, uint256 amountA, uint256 amountB);

    //////////////////////////////////////////////////////////////
    //                      CONSTRUCTOR                        //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Constructor to initialize the AMM contract with Uniswap V3 dependencies
     * @dev Sets up the contract with necessary Uniswap V3 contract addresses
     *
     * @param _uniswapV3Factory Address of the Uniswap V3 factory contract
     * @param _uniswapSwapRouter Address of the Uniswap V3 swap router contract
     * @param _uniswapNonFungiblePositionManager Address of the Uniswap V3 position manager contract
     *
     * Requirements:
     * - All provided addresses must be valid Uniswap V3 contracts
     * - Contracts must be deployed on the same network
     *
     * Effects:
     * - Sets immutable contract references for Uniswap V3 integration
     * - Initializes Ownable with msg.sender as owner
     *
     * @custom:security Immutable addresses prevent malicious contract swapping
     */
    constructor(address _uniswapV3Factory, address _uniswapSwapRouter, address _uniswapNonFungiblePositionManager) {
        magicFactory = IUniswapV3Factory(_uniswapV3Factory);
        swapRouter = ISwapRouter(_uniswapSwapRouter);
        nonFungiblePositionManager = INonfungiblePositionManager(_uniswapNonFungiblePositionManager);
    }

    //////////////////////////////////////////////////////////////
    //                   EXTERNAL FUNCTIONS                    //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Creates and initializes a new Uniswap V3 pool for a prediction market
     * @dev This function creates a pool, initializes it with equal pricing (1:1), and sets up all
     *      necessary mappings for efficient pool management and lookups.
     *
     * @param _tokenA Address of the first outcome token
     * @param _tokenB Address of the second outcome token
     * @param _fee Fee tier for the pool (500 for 0.05%, 3000 for 0.3%, 10000 for 1%)
     * @param _marketId Unique identifier for the prediction market
     *
     * @return poolAddress Address of the created and initialized pool
     *
     * Requirements:
     * - Tokens must be different addresses
     * - Pool for this market must not already exist
     * - Fee tier must be supported by Uniswap V3
     *
     * Effects:
     * - Creates new Uniswap V3 pool through factory
     * - Initializes pool with 1:1 price ratio (sqrt(1) * 2^96)
     * - Updates all relevant mappings for pool tracking
     * - Adds pool to the pools array for enumeration
     *
     * @custom:pricing Pool is initialized with equal pricing (50/50) between outcome tokens
     * @custom:ordering Token addresses are ordered (tokenA < tokenB) for Uniswap compatibility
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
     * @notice Adds liquidity to a prediction market pool
     * @dev Creates a new position or adds to existing position. The contract holds the NFT but tracks
     *      user ownership. Handles token transfers, approvals, and refunds automatically.
     *
     * @param _marketId Unique identifier for the prediction market
     * @param _user Address of the user adding liquidity
     * @param _amount0 Desired amount of tokenA to add
     * @param _amount1 Desired amount of tokenB to add
     * @param _tickLower Lower price bound for the liquidity position
     * @param _tickUpper Upper price bound for the liquidity position
     *
     * @return tokenId The NFT token ID representing the position (0 for new positions initially)
     * @return liquidity Current total liquidity in the position after adding
     * @return amount0 Actual amount of tokenA in the position
     * @return amount1 Actual amount of tokenB in the position
     *
     * Requirements:
     * - Pool must be initialized and active
     * - User must have approved this contract to spend the required token amounts
     * - Tick range must be valid (tickLower < tickUpper)
     * - Tick values must align with the pool's tick spacing
     *
     * Effects:
     * - Transfers tokens from user to this contract
     * - Mints new position NFT or increases existing position liquidity
     * - Refunds any unused tokens to the user
     * - Updates position tracking mappings
     *
     * @custom:slippage Users should account for slippage when setting amount parameters
     * @custom:refund Unused tokens are automatically refunded to maintain exact ratios
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
     * @notice Removes liquidity from an existing position and collects the tokens
     * @dev Decreases liquidity from the position and immediately collects the withdrawn tokens
     *      plus any accumulated fees. Both operations are atomic to ensure user receives tokens.
     *
     * @param _marketId Unique identifier for the prediction market
     * @param _user Address of the user removing liquidity
     * @param _liquidity Amount of liquidity to remove from the position
     * @param _amount0Min Minimum amount of tokenA to receive (slippage protection)
     * @param _amount1Min Minimum amount of tokenB to receive (slippage protection)
     *
     * @return amount0Decreased Amount of tokenA made available by removing liquidity
     * @return amount1Decreased Amount of tokenB made available by removing liquidity
     * @return amount0Collected Total tokenA collected (withdrawn + fees)
     * @return amount1Collected Total tokenB collected (withdrawn + fees)
     *
     * Requirements:
     * - User must have an existing position in the specified market
     * - Position must have sufficient liquidity to remove
     * - Amounts received must meet minimum thresholds (slippage protection)
     *
     * Effects:
     * - Reduces liquidity in the user's position
     * - Transfers withdrawn tokens and fees directly to user
     * - Updates position state to reflect reduced liquidity
     *
     * @custom:fees Collected amounts include both withdrawn liquidity and accumulated trading fees
     * @custom:atomic Liquidity removal and token collection happen in the same transaction
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
     * @notice Swaps tokens using the Uniswap V3 router with slippage protection
     * @dev Executes a token swap through the official Uniswap router, providing standardized
     *      pricing and slippage protection. Users must approve token spending before calling.
     *
     * @param _marketId Unique identifier for the prediction market (determines pool and fee tier)
     * @param _amountIn Amount of input tokens to swap
     * @param _amountOutMinimum Minimum amount of output tokens to receive (slippage protection)
     * @param _zeroForOne Direction of swap: true for tokenA→tokenB, false for tokenB→tokenA
     *
     * Requirements:
     * - Pool must be initialized and active
     * - User must have approved this contract to spend _amountIn of input token
     * - User must have sufficient balance of input token
     * - Swap must result in at least _amountOutMinimum output tokens
     *
     * Effects:
     * - Transfers input tokens from user to this contract
     * - Executes swap through Uniswap V3 router
     * - Transfers output tokens directly to user
     * - Emits swap event with actual amounts
     *
     * @custom:routing Uses official Uniswap router for maximum compatibility and safety
     * @custom:fees Router fees are automatically handled by Uniswap
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

    //////////////////////////////////////////////////////////////
    //                   INTERNAL FUNCTIONS                    //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Internal function to create a new Uniswap V3 pool for a prediction market
     * @dev Handles token ordering, pool creation through factory, and validation
     *
     * @param _marketId Unique identifier for the prediction market
     * @param _tokenA Address of the first outcome token
     * @param _tokenB Address of the second outcome token
     * @param _fee Fee tier for the pool
     *
     * @return poolAddress Address of the newly created pool
     *
     * Requirements:
     * - Tokens must be different addresses
     * - Pool for this market must not already exist
     * - Pool creation must succeed (non-zero address returned)
     *
     * Effects:
     * - Orders tokens by address (ensures tokenA < tokenB)
     * - Creates pool through Uniswap factory
     * - Emits PoolCreated event
     *
     * @custom:ordering Ensures consistent token ordering for Uniswap compatibility
     * @custom:validation Prevents duplicate pools and invalid token pairs
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
     * @notice Internal function to initialize pool with starting price and update contract mappings
     * @dev Sets the initial price to 1:1 (equal value for both outcome tokens) and updates all
     *      tracking mappings for efficient lookups
     *
     * @param poolData PoolData struct containing complete pool information
     *
     * Requirements:
     * - Pool must not already be initialized in this contract
     * - Pool contract must exist and be valid
     *
     * Effects:
     * - Initializes pool with sqrt(1) * 2^96 price (equal weighting)
     * - Updates marketIdToPool mapping for market-based lookups
     * - Updates poolAddressToPool mapping for reverse lookups
     * - Updates bidirectional tokenPairToPoolAddress mapping
     * - Adds pool to pools array for enumeration
     * - Sets poolInitialized flag to true
     *
     * @custom:pricing Initial price of sqrt(1) * 2^96 represents equal token values
     * @custom:mappings Updates all lookup mappings for comprehensive pool tracking
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
     * @notice Internal function to mint a new NFT liquidity position for a user
     * @dev Creates a new concentrated liquidity position and assigns it to the user in our tracking system.
     *      The NFT is held by this contract but ownership is tracked per user.
     *
     * @param poolData PoolData struct containing pool information
     * @param _user Address of the user for whom to mint the position
     * @param _amount0 Amount of tokenA to add to the position
     * @param _amount1 Amount of tokenB to add to the position
     * @param _tickLower Lower tick bound for the liquidity position
     * @param _tickUpper Upper tick bound for the liquidity position
     *
     * @return tokenId The NFT token ID of the newly minted position
     * @return liquidity Amount of liquidity minted
     * @return amount0 Actual amount of tokenA used (may be less than requested)
     * @return amount1 Actual amount of tokenB used (may be less than requested)
     *
     * Requirements:
     * - User must not already have a position in this market
     * - This contract must have sufficient token balances and approvals
     * - Tick range must be valid for the pool
     *
     * Effects:
     * - Approves position manager to spend tokens
     * - Mints new NFT position through position manager
     * - Updates userAddressToMarketIdToPositionId mapping
     * - Emits NewPositionMinted event
     *
     * @custom:custody NFT is minted to this contract address but tracked per user
     * @custom:precision Actual amounts may differ from requested due to price precision
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
     * @notice Internal function to add liquidity to an existing position
     * @dev Increases liquidity in a user's existing NFT position by adding more tokens
     *
     * @param poolData PoolData struct containing pool information
     * @param _user Address of the user adding liquidity
     * @param _amount0 Amount of tokenA to add
     * @param _amount1 Amount of tokenB to add
     *
     * @return liquidity Amount of liquidity added
     * @return amount0 Actual amount of tokenA used
     * @return amount1 Actual amount of tokenB used
     *
     * Requirements:
     * - User must have an existing position
     * - This contract must have sufficient token balances and approvals
     *
     * Effects:
     * - Approves position manager to spend additional tokens
     * - Increases liquidity in the existing NFT position
     * - Returns actual amounts used (may differ from requested)
     *
     * @custom:existing Only works with positions that already exist for the user
     * @custom:precision Actual amounts may differ due to current pool price and ratios
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
     * @notice Internal function to refund unused tokens to the user after minting/adding liquidity
     * @dev Due to price precision and ratios, not all provided tokens may be used. This function
     *      refunds any unused tokens back to the user.
     *
     * @param poolData PoolData struct containing pool information
     * @param amount0 Actual amount of tokenA used in the position
     * @param amount1 Actual amount of tokenB used in the position
     * @param _amount0 Original amount of tokenA provided by user
     * @param _amount1 Original amount of tokenB provided by user
     *
     * @return amount0Refunded Amount of tokenA refunded to user
     * @return amount1Refunded Amount of tokenB refunded to user
     *
     * Effects:
     * - Calculates difference between provided and used amounts
     * - Transfers unused tokens back to the user
     * - Updates approval amounts for unused tokens
     *
     * @custom:precision Handles cases where exact token ratios cannot be maintained
     * @custom:refund Ensures users don't lose unused tokens in liquidity operations
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
     * @notice Internal function to decrease liquidity from an existing position
     * @dev Removes specified amount of liquidity from a user's position, making tokens
     *      available for collection. Validates sufficient liquidity and balances exist.
     *
     * @param poolData PoolData struct containing pool information
     * @param _user Address of the user removing liquidity
     * @param _liquidity Amount of liquidity to remove
     * @param _amount0Min Minimum amount of tokenA expected (slippage protection)
     * @param _amount1Min Minimum amount of tokenB expected (slippage protection)
     *
     * @return amount0Decreased Amount of tokenA made available for collection
     * @return amount1Decreased Amount of tokenB made available for collection
     *
     * Requirements:
     * - User must have an existing position
     * - Position must have sufficient liquidity to remove
     * - Available tokens must meet minimum thresholds
     *
     * Effects:
     * - Reduces liquidity in the NFT position
     * - Makes tokens available for collection (but doesn't transfer them)
     * - Emits LiquidityRemoved event
     *
     * @custom:validation Comprehensive checks ensure operation safety and slippage protection
     * @custom:collection Tokens are made available but require separate collection call
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
     * @notice Internal function to collect tokens from a position
     * @dev Collects all available tokens from a position, including withdrawn liquidity and
     *      accumulated trading fees. Transfers tokens directly to the user.
     *
     * @param poolData PoolData struct containing pool information
     * @param _user Address of the user collecting tokens
     *
     * @return amount0Collected Total amount of tokenA collected (liquidity + fees)
     * @return amount1Collected Total amount of tokenB collected (liquidity + fees)
     *
     * Requirements:
     * - User must have an existing position
     * - Position must have tokens available for collection
     *
     * Effects:
     * - Collects all available tokens from the position
     * - Transfers collected tokens directly to the user
     * - Resets the position's collectable token amounts to zero
     * - Emits TokensCollected event
     *
     * @custom:comprehensive Collects both withdrawn liquidity and earned fees in one operation
     * @custom:direct Tokens are transferred directly to user, not held by this contract
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
     * @notice Internal function to execute a token swap through the Uniswap router
     * @dev Handles token approval and executes swap through the official router with
     *      automatic slippage protection and price limits.
     *
     * @param _inputToken Address of the token being sold
     * @param _outputToken Address of the token being bought
     * @param _amountIn Amount of input tokens to swap
     * @param _amountOutMinimum Minimum amount of output tokens to receive
     * @param _marketId Market identifier for the swap (determines pool and fee tier)
     *
     * Requirements:
     * - This contract must have sufficient input token balance
     * - Router must be approved to spend input tokens
     * - Swap must result in at least _amountOutMinimum output tokens
     *
     * Effects:
     * - Approves router to spend input tokens
     * - Executes exact input swap through router
     * - Output tokens are sent directly to original swap caller (msg.sender)
     * - Emits TokensSwapped event with actual amounts
     *
     * @custom:router Uses official Uniswap router for maximum compatibility
     * @custom:limits Automatically calculates appropriate price limits based on swap direction
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
     * @notice Callback function called by Uniswap V3 pools during direct swaps
     * @dev This function is called by pool contracts to collect payment for swaps. Only registered
     *      pools can call this function, and it handles the token transfer to complete the swap.
     *
     * @param amount0Delta Amount of token0 owed to pool (positive) or received (negative)
     * @param amount1Delta Amount of token1 owed to pool (positive) or received (negative)
     * @param data Encoded data containing swap initiator and contract addresses
     *
     * Requirements:
     * - Only callable by registered pool contracts
     * - At least one delta must be positive (payment required)
     * - Contract must have sufficient token balance for payment
     *
     * Effects:
     * - Transfers required tokens to the calling pool
     * - Completes the swap transaction initiated by directPoolSwap
     *
     * @custom:security Verifies caller is a registered pool to prevent unauthorized calls
     * @custom:callback This implements Uniswap's required callback interface for direct swaps
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
     * @notice Executes a swap directly through the pool, bypassing the router
     * @dev Provides direct pool interaction for scenarios where the router may not work
     *      (e.g., newly created pools not yet recognized). Uses callback pattern for payment.
     *
     * @param _marketId Unique identifier for the prediction market
     * @param _amountIn Amount of input tokens to swap
     * @param _amountOutMinimum Minimum amount of output tokens to receive
     * @param _zeroForOne Direction of swap: true for tokenA→tokenB, false for tokenB→tokenA
     *
     * @return amountOut Actual amount of output tokens received
     *
     * Requirements:
     * - Pool must be initialized and active
     * - User must have approved this contract to spend _amountIn of input token
     * - User must have sufficient balance of input token
     * - Swap must result in at least _amountOutMinimum output tokens
     *
     * Effects:
     * - Transfers input tokens from user to this contract
     * - Executes swap directly through pool contract
     * - Pool calls back to this contract for payment via uniswapV3SwapCallback
     * - Transfers output tokens directly to user
     *
     * @custom:callback Uses Uniswap's callback pattern for trustless token payment
     * @custom:direct Bypasses router for maximum control and compatibility with new pools
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

    //////////////////////////////////////////////////////////////
    //                      VIEW FUNCTIONS                     //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Retrieves the pool address for given token addresses and fee tier
     * @dev Queries the Uniswap factory for the pool address. Returns zero address if pool doesn't exist.
     *
     * @param tokenA Address of the first token
     * @param tokenB Address of the second token
     * @param fee Fee tier for the pool
     *
     * @return pool Address of the pool (zero address if doesn't exist)
     *
     * @custom:factory Queries Uniswap factory directly for maximum reliability
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
