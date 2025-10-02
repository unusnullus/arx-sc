// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/console2.sol";
import { ARX } from "../src/ARX.sol";
import { ArxTokenSale } from "../src/ArxTokenSale.sol";
import { MockUSDC } from "../src/mocks/MockUSDC.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

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

        // Deploy ARX implementation and proxy
        ARX arxImpl = new ARX();
        bytes memory dataArx = abi.encodeWithSelector(ARX.initialize.selector, owner);
        ERC1967Proxy arxProxy = new ERC1967Proxy(address(arxImpl), dataArx);
        ARX arx = ARX(address(arxProxy));

        // Deploy Sale implementation and proxy
        ArxTokenSale saleImpl = new ArxTokenSale();
        bytes memory dataSale = abi.encodeWithSelector(
            ArxTokenSale.initialize.selector, owner, IERC20(address(usdc)), arx, owner, 5_000_000
        );
        ERC1967Proxy saleProxy = new ERC1967Proxy(address(saleImpl), dataSale);
        ArxTokenSale sale = ArxTokenSale(address(saleProxy));

        arx.grantRole(arx.MINTER_ROLE(), address(sale));
        console.log("USDC:", address(usdc));
        console.log("ARX:", address(arx));
        console.log("SALE:", address(sale));
        vm.stopBroadcast();
    }
}
