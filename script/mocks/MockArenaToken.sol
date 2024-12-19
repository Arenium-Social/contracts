// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockArenaToken is ERC20Burnable {
    uint256 public constant supply = 10_000_000_000;

    uint256 public constant treasuryAllocationPercentage = 320;
    uint256 public constant ecosystemAllocationPercentageUnlocked = 37;
    uint256 public constant ecosystemAllocationPercentage = 370 - ecosystemAllocationPercentageUnlocked;
    uint256 public constant airdropAllocationPercentage = 310;

    constructor(string memory name, string memory symbol, address distributor) ERC20(name, symbol) {
        require(distributor != address(0), "Invalid address");

        _mint(distributor, supply * 10 ** 18);
        //slither-disable-end divide-before-multiply
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
