// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {ARX} from "../src/ARX.sol";
import {ArxTokenSale} from "../src/ArxTokenSale.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LocalDeploy is Script {
    function run() external {
        // Use default anvil first account if PRIVATE_KEY not set
        uint256 pk;
        try vm.envUint("PRIVATE_KEY") returns (uint256 _pk) {
            pk = _pk;
        } catch {
            pk = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        }
        address owner = vm.addr(pk);
        vm.startBroadcast(pk);
        MockUSDC usdc = new MockUSDC();
        usdc.mint(owner, 1_000_000e6);
        ARX arx = new ARX(owner);
        ArxTokenSale sale = new ArxTokenSale(owner, IERC20(address(usdc)), arx, owner, 5_000_000);
        arx.grantRole(arx.MINTER_ROLE(), address(sale));
        console.log("USDC:", address(usdc));
        console.log("ARX:", address(arx));
        console.log("SALE:", address(sale));
        vm.stopBroadcast();
    }
}


