// // SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {PredictionMarket} from "../../src/PredictionMarket.sol";
import {AMMContract} from "../../src/AMMContract.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/**
 * @title AddLiquidityScript
 * @author Your Name/Organization
 * @notice Foundry deployment script for adding liquidity to a prediction market
 * @dev This script creates outcome token liquidity in a prediction market by:
 *      1. Configuring network-specific parameters via HelperConfig
 *      2. Approving USDC spending for the prediction market contract
 *      3. Reading current tick data from a Uniswap V3 pool
 *      4. Creating liquidity position with specified tick range
 * 
 * @custom:security This script uses hardcoded addresses - ensure they match your deployment network
 * @custom:network Currently configured for Base Sepolia testnet
 */
contract AddLiquidityScript is Script {
    /**
     * @notice Main execution function that adds liquidity to the prediction market
     * @dev Executes the following workflow:
     *      1. Loads Base Sepolia network configuration
     *      2. Connects to deployed AMM and PredictionMarket contracts
     *      3. Approves USDC token spending (1 USDC = 1e6 units)
     *      4. Retrieves current tick from Uniswap V3 pool for price reference
     *      5. Creates liquidity position with symmetric tick range (-120 to +120)
     * 
     * @custom:broadcast This function uses vm.startBroadcast()/vm.stopBroadcast() for transaction execution
     * @custom:gas-optimization Consider batching operations to reduce gas costs in production
     * 
     * Requirements:
     * - Caller must have sufficient USDC balance (at least 1e6 units)
     * - Prediction market contract must be properly deployed and functional
     * - Network configuration must match the target deployment environment
     * 
     * Emits:
     * - Console logs for tick value and generated token ID
     * - Events from PredictionMarket.createOutcomeTokensLiquidity()
     */
    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config;
        config = helperConfig.getBaseSepoliaConfig();

        vm.startBroadcast();
        AMMContract amm = AMMContract(0xD12355D121eDee77DbC4D1Abdf01A965409170e4);
        PredictionMarket predictionMarket = PredictionMarket(0x82622311068D890a5224B6370ca8012f02913911);

        IERC20 currency = IERC20(config.usdc);
        currency.approve(address(predictionMarket), 1e6);
        (, int24 tick,,,,,) = IUniswapV3Pool(0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2).slot0();
        uint256 tokenId = predictionMarket.createOutcomeTokensLiquidity(
            0x4d3b7461ff3a537673f332bbdf2775907850d4e7ed4bfcf9fe7860cea0b534da, 1e6, -120, 120
        );

        console2.log("Tick", tick);
        console2.log("TokenId", tokenId);
        vm.stopBroadcast();
    }
}
