// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ClaimVault, ISwapRouterV3 } from "../src/claimable/ClaimVault.sol";

contract DeployClaimVault is Script {
    function run() external {
        string memory pkString = vm.envString("PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(
            bytes(pkString).length == 64 ? string(abi.encodePacked("0x", pkString)) : pkString
        );
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);

        address usdc = vm.envAddress("USDC");
        address usdt = vm.envAddress("USDT");
        address weth = vm.envAddress("WETH");
        address swapRouter = vm.envAddress("UNISWAP_V3_ROUTER");

        vm.startBroadcast(deployerPrivateKey);
        ClaimVault vault =
            new ClaimVault(IERC20(usdc), IERC20(usdt), IERC20(weth), ISwapRouterV3(swapRouter));
        vm.stopBroadcast();

        console.log("ClaimVault deployed at:", address(vault));
    }
}
