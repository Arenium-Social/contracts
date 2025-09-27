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
}
