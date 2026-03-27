// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ClaimVault } from "../src/claimable/ClaimVault.sol";

contract DeployClaimVault is Script {
    function run() external {
        string memory pkString = vm.envString("PRIVATE_KEY");
        uint256 deployerPrivateKey = vm.parseUint(
            bytes(pkString).length == 64 ? string(abi.encodePacked("0x", pkString)) : pkString
        );
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);
        ClaimVault vault = new ClaimVault();
        vm.stopBroadcast();

        console.log("ClaimVault deployed at:", address(vault));
    }
}
