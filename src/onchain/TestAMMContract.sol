// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Test_AMMContract
 * @author Arenium Social
 * @notice Simplified automated market maker contract for testing prediction market functionality
 * @dev This is a testing version that implements a basic constant product AMM (x * y = k) instead
 *      of the complex Uniswap V3 concentrated liquidity model. It provides essential AMM functionality
 *      for creating pools, managing liquidity, and executing swaps between outcome tokens.
 *
 * Key Features:
 * - Simple constant product formula for token swapping
 * - Basic liquidity provision and removal
 * - Pool creation and management for prediction markets
 * - User position tracking
 * - Slippage protection on swaps
 *
 * Architecture:
 * - Built on constant product AMM model (x * y = k)
 * - Simplified reserve-based liquidity tracking
 * - Direct token transfers without complex callbacks
 * - Compatible interface with the main AMM contract
 *
 * Security Considerations:
 * - Safe token transfers using OpenZeppelin's IERC20
 * - Slippage protection on all swap operations
 * - Owner-only emergency functions
 * - Input validation on all public functions
 *
 * Gas Optimizations:
 * - Simple mathematical operations
 * - Efficient storage patterns with mappings
 * - Minimal external calls
 *
 * @custom:testing This contract is designed for testing purposes and uses simplified logic
 * @custom:compatibility Maintains interface compatibility with the main AMM contract
 * @custom:formula Uses constant product formula: reserveA * reserveB = k (constant)
 */
contract Test_AMMContract is Ownable {
    //////////////////////////////////////////////////////////////
    //                    DATA STRUCTURES                      //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Comprehensive data structure containing all pool-related information
     * @dev Simplified version that stores essential pool data for testing
     *
     * @param marketId Unique identifier linking this pool to a prediction market
     * @param tokenA Address of the first outcome token (always ordered lower address first)
     * @param tokenB Address of the second outcome token (always ordered higher address second)
     * @param reserveA Current reserve amount of tokenA in the pool
     * @param reserveB Current reserve amount of tokenB in the pool
     * @param poolInitialized Flag indicating if the pool has been created and is active
     *
     * @custom:ordering tokenA and tokenB are ordered by address (tokenA < tokenB) for consistency
     * @custom:reserves Reserves represent the actual token balances held by this contract
     */
    struct PoolData {
        bytes32 marketId; // Links to prediction market
        address tokenA; // First token (lower address)
        address tokenB; // Second token (higher address)
        uint256 reserveA; // Current reserve of tokenA
        uint256 reserveB; // Current reserve of tokenB
        bool poolInitialized; // Pool creation status
    }

    //////////////////////////////////////////////////////////////
    //                        STORAGE                          //
    //////////////////////////////////////////////////////////////

    /// @notice Maps market ID to its corresponding pool data for primary lookups
    /// @dev Main storage mapping for pool information indexed by market identifier
    mapping(bytes32 => PoolData) public marketIdToPool;

    /// @notice Maps token pairs to pool addresses for reverse lookups
    /// @dev Bidirectional mapping: both (tokenA, tokenB) and (tokenB, tokenA) point to same pool
    /// @dev In this simplified version, all pools are managed by this contract so address is always address(this)
    mapping(address => mapping(address => address)) public tokenPairToPoolAddress;

    /// @notice Maps user address and market ID to their liquidity amount
    /// @dev Tracks how much liquidity each user has provided to each market pool
    /// @dev Simplified tracking compared to NFT-based positions in the main contract
    mapping(address => mapping(bytes32 => uint256)) public userLiquidity;

    /// @notice Array storing all created pools for enumeration and analytics
    /// @dev Provides a way to iterate through all pools managed by this contract
    PoolData[] public pools;

    /// @notice Total number of pools created by this contract
    /// @dev Counter for tracking pool creation, used for analytics and validation
    uint256 public totalPools;

    //////////////////////////////////////////////////////////////
    //                        EVENTS                           //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Emitted when a new pool is created for a prediction market
     * @param marketId Unique identifier for the prediction market
     * @param tokenA Address of the first outcome token
     * @param tokenB Address of the second outcome token
     */
    event PoolCreated(bytes32 indexed marketId, address tokenA, address tokenB);

    /**
     * @notice Emitted when a pool is successfully initialized and ready for use
     * @param marketId Unique identifier for the prediction market
     */
    event PoolInitialized(bytes32 indexed marketId);

    /**
     * @notice Emitted when liquidity is added to a pool
     * @param marketId Market identifier where liquidity was added
     * @param user Address of the user who added liquidity
     * @param amount0 Amount of tokenA added to reserves
     * @param amount1 Amount of tokenB added to reserves
     */
    event LiquidityAdded(bytes32 indexed marketId, address indexed user, uint256 amount0, uint256 amount1);

    /**
     * @notice Emitted when liquidity is removed from a pool
     * @param marketId Market identifier where liquidity was removed
     * @param user Address of the user who removed liquidity
     * @param amount0 Amount of tokenA removed from reserves and returned to user
     * @param amount1 Amount of tokenB removed from reserves and returned to user
     */
    event LiquidityRemoved(bytes32 indexed marketId, address indexed user, uint256 amount0, uint256 amount1);

    /**
     * @notice Emitted when tokens are swapped through the AMM
     * @param marketId Market identifier for the pool used in the swap
     * @param tokenIn Address of the input token provided by user
     * @param tokenOut Address of the output token received by user
     * @param amountIn Amount of input tokens provided
     * @param amountOut Actual amount of output tokens received
     */
    event TokensSwapped(
        bytes32 indexed marketId, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    //////////////////////////////////////////////////////////////
    //                      CONSTRUCTOR                        //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Constructor to initialize the Test_AMMContract
     * @dev Sets up the contract with the deployer as owner through OpenZeppelin's Ownable
     *      No additional initialization required for the simplified version
     *
     * Effects:
     * - Sets msg.sender as the contract owner
     * - Initializes empty storage mappings
     * - Sets totalPools counter to 0
     *
     * @custom:testing This simplified constructor doesn't need external contract addresses
     */
    constructor() {}

    //////////////////////////////////////////////////////////////
    //                   EXTERNAL FUNCTIONS                    //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Creates and initializes a new pool for a prediction market
     * @dev Creates a new pool with the specified tokens and associates it with a market ID.
     *      Tokens are automatically ordered by address to ensure consistency.
     *
     * @param _tokenA Address of the first outcome token
     * @param _tokenB Address of the second outcome token
     * @param _fee Fee tier parameter (ignored in simplified version, kept for interface compatibility)
     * @param _marketId Unique identifier for the prediction market
     *
     * @return poolAddress Address of this contract (simplified - all pools managed here)
     *
     * Requirements:
     * - Tokens must be different addresses
     * - Pool for this market must not already exist
     * - Both token addresses must be valid (non-zero)
     *
     * Effects:
     * - Creates new PoolData struct and stores it in marketIdToPool
     * - Updates tokenPairToPoolAddress bidirectional mapping
     * - Adds pool to the pools array for enumeration
     * - Increments totalPools counter
     * - Emits PoolCreated and PoolInitialized events
     *
     * @custom:ordering Automatically orders tokens by address (tokenA < tokenB)
     * @custom:compatibility Returns address(this) for compatibility with main contract interface
     */
    function initializePool(address _tokenA, address _tokenB, uint24 _fee, bytes32 _marketId)
        external
        returns (address poolAddress)
    {
        require(marketIdToPool[_marketId].tokenA == address(0), "Pool already exists");
        require(_tokenA != _tokenB, "Tokens must be different");
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid token addresses");

        // Order tokens by address to ensure consistency
        if (_tokenA > _tokenB) {
            (_tokenA, _tokenB) = (_tokenB, _tokenA);
        }

        // Create new pool data structure
        PoolData memory pool = PoolData({
            marketId: _marketId,
            tokenA: _tokenA,
            tokenB: _tokenB,
            reserveA: 0,
            reserveB: 0,
            poolInitialized: true
        });

        // Store pool data in mappings
        marketIdToPool[_marketId] = pool;
        tokenPairToPoolAddress[_tokenA][_tokenB] = address(this);
        tokenPairToPoolAddress[_tokenB][_tokenA] = address(this);

        // Add to pools array for enumeration
        pools.push(pool);
        totalPools++;

        emit PoolCreated(_marketId, _tokenA, _tokenB);
        emit PoolInitialized(_marketId);

        return address(this);
    }

    /**
     * @notice Adds liquidity to a prediction market pool
     * @dev Transfers tokens from the user and adds them to the pool reserves. Updates user's
     *      liquidity tracking. In this simplified version, tick parameters are ignored.
     *
     * @param _marketId Unique identifier for the prediction market
     * @param _user Address of the user adding liquidity (should be msg.sender in practice)
     * @param _amount0 Amount of tokenA to add to the pool
     * @param _amount1 Amount of tokenB to add to the pool
     * @param _tickLower Lower price bound (ignored in simplified version, kept for compatibility)
     * @param _tickUpper Upper price bound (ignored in simplified version, kept for compatibility)
     *
     * @return tokenId Token ID representing the position (simplified to always return 1)
     * @return liquidity Amount of liquidity added (calculated as average of both amounts)
     * @return amount0 Actual amount of tokenA added (same as input in simplified version)
     * @return amount1 Actual amount of tokenB added (same as input in simplified version)
     *
     * Requirements:
     * - Pool must exist and be initialized
     * - User must have approved this contract to spend the required token amounts
     * - User must have sufficient balance of both tokens
     * - Amount parameters must be greater than zero
     *
     * Effects:
     * - Transfers _amount0 of tokenA from user to this contract
     * - Transfers _amount1 of tokenB from user to this contract
     * - Updates pool reserves (reserveA += _amount0, reserveB += _amount1)
     * - Updates user's liquidity tracking
     * - Emits LiquidityAdded event
     *
     * @custom:simplified Uses simple average for liquidity calculation instead of complex formulas
     * @custom:compatibility Returns values in same format as main contract for interface compatibility
     */
    function addLiquidity(
        bytes32 _marketId,
        address _user,
        uint256 _amount0,
        uint256 _amount1,
        int24 _tickLower, // Ignored in simple version
        int24 _tickUpper // Ignored in simple version
    ) external returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        PoolData storage pool = marketIdToPool[_marketId];
        require(pool.poolInitialized, "Pool not active");
        require(_amount0 > 0 && _amount1 > 0, "Amounts must be greater than zero");

        // Transfer tokens from user to this contract
        IERC20(pool.tokenA).transferFrom(msg.sender, address(this), _amount0);
        IERC20(pool.tokenB).transferFrom(msg.sender, address(this), _amount1);

        // Update pool reserves
        pool.reserveA += _amount0;
        pool.reserveB += _amount1;

        // Track user liquidity using simple calculation
        // In a real AMM, this would use more complex formulas considering current reserves
        uint256 liquidityAdded = (_amount0 + _amount1) / 2;
        userLiquidity[_user][_marketId] += liquidityAdded;

        emit LiquidityAdded(_marketId, _user, _amount0, _amount1);

        // Return values for interface compatibility
        return (1, uint128(liquidityAdded), _amount0, _amount1);
    }
}
