// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@uma/core/contracts/data-verification-mechanism/interfaces/FinderInterface.sol";

contract MockFinder is FinderInterface {
    mapping(bytes32 => address) public implementations;

    function changeImplementationAddress(bytes32 interfaceName, address implementationAddress) external override {
        implementations[interfaceName] = implementationAddress;
    }

    function getImplementationAddress(bytes32 interfaceName) external view override returns (address) {
        address implementation = implementations[interfaceName];
        require(implementation != address(0), "No implementation set for interface");
        return implementation;
    }
}
