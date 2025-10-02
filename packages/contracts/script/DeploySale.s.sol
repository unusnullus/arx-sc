// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { ArxTokenSale } from "../src/ArxTokenSale.sol";
import { IARX } from "../src/ARX.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeploySale is Script {
    function run() external returns (ArxTokenSale sale) {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);
        vm.startBroadcast(pk);
        address usdc = vm.envAddress("USDC");
        address arx = vm.envAddress("ARX");
        address silo = vm.envAddress("SILO_TREASURY");
        uint256 price = vm.envUint("ARX_PRICE_USDC_6DP");
        ArxTokenSale impl = new ArxTokenSale();
        bytes memory data = abi.encodeWithSelector(
            ArxTokenSale.initialize.selector, owner, IERC20(usdc), IARX(arx), silo, price
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), data);
        sale = ArxTokenSale(address(proxy));
        vm.stopBroadcast();
    }
}
