// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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
        address finder;
        address currency;
        address optimisticOracleV3;
    }

    /*//////////////////////////////////////////////////////////////
                                CONFIGS
    //////////////////////////////////////////////////////////////*/
    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory SepoliaConfig = NetworkConfig({
            finder: 0xf4C48eDAd256326086AEfbd1A53e1896815F8f13,
            currency: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238, // Testnet USDC address
            optimisticOracleV3: 0xFd9e2642a170aDD10F53Ee14a93FcF2F31924944
        });
        return SepoliaConfig;
    }

    function getBaseSepoliaConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory BaseSepoliaConfig = NetworkConfig({
            finder: 0xfF4Ec014E3CBE8f64a95bb022F1623C6e456F7dB,
            currency: 0x036CbD53842c5426634e7929541eC2318f3dCF7e, // Testnet USDC address
            optimisticOracleV3: 0x0F7fC5E6482f096380db6158f978167b57388deE
        });
        return BaseSepoliaConfig;
    }

    // AVAX C-MAINNET LAUNCH
    function getAvaxCChainConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory AvaxCChainConfig = NetworkConfig({
            finder: 0xCFdC4d6FdeC25e339ef07e25C35a482A6bedcfE0,
            currency: 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E, // Mainnet USDC address
            optimisticOracleV3: 0xa4199d73ae206d49c966cF16c58436851f87d47F
        });
        return AvaxCChainConfig;
    }

    /*//////////////////////////////////////////////////////////////
                              LOCAL CONFIG
    //////////////////////////////////////////////////////////////*/
    function getAnvilConfig() public pure returns (NetworkConfig memory) {
        console2.log("Testing On Anvil Network");
        NetworkConfig memory AnvilConfig =
            NetworkConfig({finder: address(1), currency: address(2), optimisticOracleV3: address(3)});
        return AnvilConfig;
    }
}
