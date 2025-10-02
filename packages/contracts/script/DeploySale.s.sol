// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { ArxTokenSale } from "../src/ArxTokenSale.sol";
import { IARX } from "../src/ARX.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeploySale is Script {
    function run() external returns (ArxTokenSale sale) {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);
        vm.startBroadcast(pk);
        address usdc = vm.envAddress("USDC");
        address arx = vm.envAddress("ARX");
        address silo = vm.envAddress("SILO_TREASURY");
        uint256 price = vm.envUint("ARX_PRICE_USDC_6DP");
        sale = new ArxTokenSale(owner, IERC20(usdc), IARX(arx), silo, price);
        vm.stopBroadcast();
    }
}
