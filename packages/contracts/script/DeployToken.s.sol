// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {ARX} from "../src/ARX.sol";

contract DeployToken is Script {
    function run() external returns (ARX token) {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        vm.startBroadcast(pk);
        token = new ARX(deployer);
        vm.stopBroadcast();
    }
}



