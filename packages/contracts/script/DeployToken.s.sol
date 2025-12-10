// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {ARX} from "../src/token/ARX.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployToken is Script {
    function run() external returns (ARX token) {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        vm.startBroadcast(pk);

        address tokenSale = vm.envAddress("TOKEN_SALE");
        address uniswapV2Router = vm.envAddress("UNISWAP_V2_ROUTER");
        address usdc = vm.envAddress("USDC");
        address weth9 = vm.envAddress("WETH9");

        ARX impl = new ARX();
        bytes memory data = abi.encodeWithSelector(
            ARX.initialize.selector,
            deployer,
            tokenSale,
            uniswapV2Router,
            usdc,
            weth9
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), data);
        token = ARX(address(proxy));
        vm.stopBroadcast();
    }
}
