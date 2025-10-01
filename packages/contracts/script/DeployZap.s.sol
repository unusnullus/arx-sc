// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {ArxZapRouter, IWETH9, ISwapRouter, IArxTokenSale} from "../src/ArxZapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployZap is Script {
    function run() external returns (ArxZapRouter zap) {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);
        vm.startBroadcast(pk);
        address usdc = vm.envAddress("USDC");
        address weth9 = vm.envAddress("WETH9");
        address router = vm.envAddress("UNISWAP_V3_SWAPROUTER");
        zap = new ArxZapRouter(owner, IERC20(usdc), IWETH9(weth9), ISwapRouter(router));
        vm.stopBroadcast();
    }
}



