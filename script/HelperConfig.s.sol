// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Script, console2} from "forge-std/Script.sol";

contract HelperConfig is Script {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error HelperConfig__InvalidChainId();

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/
    struct NetworkConfig {
        address usdc;
        address weth;
        address finder;
        address currency;
        address optimisticOracleV3;
        address uniswapV3Factory;
        address uniswapV3SwapRouter;
        address uniswapNonFungiblePositionManager;
    }

    /*//////////////////////////////////////////////////////////////
                                CONFIGS
    //////////////////////////////////////////////////////////////*/
    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory SepoliaConfig = NetworkConfig({
            usdc: address(0),
            weth: address(0),
            finder: 0xf4C48eDAd256326086AEfbd1A53e1896815F8f13,
            currency: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238, // Testnet USDC address
            optimisticOracleV3: 0xFd9e2642a170aDD10F53Ee14a93FcF2F31924944,
            uniswapV3Factory: address(0),
            uniswapV3SwapRouter: address(0),
            uniswapNonFungiblePositionManager: address(0)
        });
        return SepoliaConfig;
    }

    function getBaseSepoliaConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory BaseSepoliaConfig = NetworkConfig({
            weth: 0x4200000000000000000000000000000000000006,
            usdc: 0x036CbD53842c5426634e7929541eC2318f3dCF7e,
            finder: 0xfF4Ec014E3CBE8f64a95bb022F1623C6e456F7dB,
            currency: 0x036CbD53842c5426634e7929541eC2318f3dCF7e, // Testnet USDC address
            optimisticOracleV3: 0x0F7fC5E6482f096380db6158f978167b57388deE,
            uniswapV3Factory: 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24,
            uniswapV3SwapRouter: 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4,
            uniswapNonFungiblePositionManager: 0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2
        });
        return BaseSepoliaConfig;
    }

    // AVAX C-MAINNET LAUNCH
    function getAvaxCChainConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory AvaxCChainConfig = NetworkConfig({
            usdc: address(0),
            weth: address(0),
            finder: 0xCFdC4d6FdeC25e339ef07e25C35a482A6bedcfE0,
            currency: 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E, // Mainnet USDC address
            optimisticOracleV3: 0xa4199d73ae206d49c966cF16c58436851f87d47F,
            uniswapV3Factory: address(0),
            uniswapV3SwapRouter: address(0),
            uniswapNonFungiblePositionManager: address(0)
        });
        return AvaxCChainConfig;
    }

    /*//////////////////////////////////////////////////////////////
                              LOCAL CONFIG
    //////////////////////////////////////////////////////////////*/
    function getAnvilConfig() public pure returns (NetworkConfig memory) {
        console2.log("Testing On Anvil Network");
        NetworkConfig memory AnvilConfig = NetworkConfig({
            usdc: address(3),
            weth: address(4),
            finder: address(1),
            currency: address(2),
            optimisticOracleV3: address(5),
            uniswapV3Factory: address(6),
            uniswapV3SwapRouter: address(7),
            uniswapNonFungiblePositionManager: address(8)
        });
        return AnvilConfig;
    }
}
