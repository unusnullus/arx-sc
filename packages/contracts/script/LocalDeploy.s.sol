// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {ARX} from "../src/token/ARX.sol";
import {ArxTokenSale} from "../src/sale/ArxTokenSale.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract LocalDeploy is Script {
    function run() external {
        // Use a default Anvil private key for local deployment
        uint256 pk = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(pk);
        vm.startBroadcast(pk);

        // Deploy MockUSDC
        MockUSDC mockUsdc = new MockUSDC();
        console.log("USDC:", address(mockUsdc));

        // Deploy ARX via proxy (with optional price params for local)
        ARX arxImpl = new ARX();
        bytes memory dataArx = abi.encodeWithSelector(
            ARX.initialize.selector,
            deployer,
            address(0), // tokenSale - set later
            address(0), // uniswapV2Router - not needed for local
            address(mockUsdc),
            address(0) // weth - not needed for local
        );
        ERC1967Proxy arxProxy = new ERC1967Proxy(address(arxImpl), dataArx);
        ARX arx = ARX(address(arxProxy));
        console.log("ARX:", address(arx));

        // Deploy ArxTokenSale via proxy
        uint256 price = 5_000_000; // 5 USDC per ARX (6dp)
        address silo = deployer; // For local testing, silo is the deployer
        ArxTokenSale saleImpl = new ArxTokenSale();
        bytes memory dataSale = abi.encodeWithSelector(
            ArxTokenSale.initialize.selector,
            deployer,
            IERC20(address(mockUsdc)),
            arx,
            silo,
            price
        );
        ERC1967Proxy saleProxy = new ERC1967Proxy(address(saleImpl), dataSale);
        ArxTokenSale sale = ArxTokenSale(address(saleProxy));
        console.log("SALE:", address(sale));

        // Grant MINTER_ROLE to the sale contract
        arx.grantRole(arx.MINTER_ROLE(), address(sale));

        vm.stopBroadcast();
    }
}
