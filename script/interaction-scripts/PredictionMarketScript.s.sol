// // SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {PredictionMarket} from "../../src/PredictionMarket.sol";
import {AMMContract} from "../../src/AMMContract.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PredictionMarketInitializeScript is Script {
    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config;
        config = helperConfig.getBaseSepoliaConfig();

        vm.startBroadcast();
        AMMContract amm = AMMContract(
            0xD12355D121eDee77DbC4D1Abdf01A965409170e4
        );
        PredictionMarket predictionMarket = PredictionMarket(
            0x82622311068D890a5224B6370ca8012f02913911
        );
        string memory tokenA = "outcome1";
        string memory tokenB = "outcome2";
        string memory description = "Test Market";
        uint256 reward = 1e8;
        uint256 requiredBond = 1e8;
        uint24 poolFee = 3000;

        IERC20(config.currency).approve(address(predictionMarket), reward);
        string memory imageURL = "";
        bytes32 marketId = predictionMarket.initializeMarket(
            tokenA,
            tokenB,
            description,
            reward,
            requiredBond,
            poolFee,
            imageURL
        );
        (
            bool resolved,
            address outcome1Token,
            address outcome2Token,
            bytes memory outcome1,
            bytes memory outcome2
        ) = predictionMarket.getMarket(marketId);
        console2.log("resolved", resolved);
        console2.log("marketId", string(abi.encode(marketId)));
        console2.log("outcome1Token", outcome1Token);
        console2.log("outcome2Token", outcome2Token);
        vm.stopBroadcast();
    }
}
