// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {ARXPool} from "../src/pool/ARXPool.sol";
import {ERC1967Proxy} from "../src/proxy/ERC1967Proxy.sol";

/// @title DeployPool
/// @notice Deployment script for ARXPool only.
/// @dev Deploys ARXPool using already deployed ARX token and USDC addresses.
///      Requires ARX and USDC addresses to be set in environment variables.
contract DeployPool is Script {
    function run() external {
        vm.startBroadcast();
        address deployer = msg.sender;

        // Get addresses from environment variables
        address arx = vm.envAddress("ARX");
        address usdc = vm.envAddress("USDC");
        address owner = vm.envOr("OWNER", deployer);

        console.log("=== Deploying ARXPool ===");
        console.log("Deployer:", deployer);
        console.log("Owner:", owner);
        console.log("ARX:", arx);
        console.log("USDC:", usdc);

        // Deploy ARXPool
        console.log("\n--- Deploying ARXPool ---");
        ARXPool poolImpl = new ARXPool();
        bytes memory dataPool = abi.encodeWithSelector(
            ARXPool.initialize.selector,
            arx,
            usdc,
            owner
        );
        ERC1967Proxy poolProxy = new ERC1967Proxy(address(poolImpl), dataPool);
        ARXPool pool = ARXPool(address(poolProxy));
        console.log("Pool Implementation:", address(poolImpl));
        console.log("Pool Proxy:", address(pool));

        vm.stopBroadcast();

        // ==================== Summary ====================
        console.log("\n=== Deployment Summary ===");
        console.log("ARXPool Proxy:", address(pool));
        console.log("\nDeployment complete!");

        // Output for easy parsing
        console.log("\n=== Addresses ===");
        console.log("ARXPool:", address(pool));

        // Output implementation address and initialization data for proxy verification
        console.log("\n=== Implementation Address (for verification) ===");
        console.log("POOL_IMPL:", address(poolImpl));
        console.log("POOL_INIT_DATA:", vm.toString(dataPool));

        // Output for .env.sepolia file
        console.log("\n=== .env.sepolia Content ===");
        console.log("NEXT_PUBLIC_ARX_POOL=", vm.toString(address(pool)));
    }
}

