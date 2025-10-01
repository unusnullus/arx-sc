// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {ARX} from "../src/ARX.sol";
import {ArxTokenSale} from "../src/ArxTokenSale.sol";
import {ArxZapRouter, IArxTokenSale} from "../src/ArxZapRouter.sol";

contract WirePermissions is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        ARX arx = ARX(vm.envAddress("ARX"));
        ArxTokenSale sale = ArxTokenSale(vm.envAddress("ARX_TOKEN_SALE"));
        ArxZapRouter payableZap = ArxZapRouter(payable(vm.envAddress("ARX_ZAP_ROUTER")));

        arx.grantRole(arx.MINTER_ROLE(), address(sale));
        payableZap.setSale(IArxTokenSale(address(sale)));
        sale.setZapper(address(payableZap), true);

        vm.stopBroadcast();
    }
}


