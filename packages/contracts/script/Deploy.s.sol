// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { ARX } from "../src/ARX.sol";
import { ArxTokenSale } from "../src/ArxTokenSale.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        vm.startBroadcast(pk);

        address usdc = vm.envAddress("USDC");
        address weth9 = vm.envAddress("WETH9");
        address swapRouter = vm.envAddress("UNISWAP_V3_SWAPROUTER");
        address silo = vm.envAddress("SILO_TREASURY");
        uint256 price = vm.envUint("ARX_PRICE_USDC_6DP");

        ARX arxImpl = new ARX();
        bytes memory dataArx = abi.encodeWithSelector(ARX.initialize.selector, deployer);
        ERC1967Proxy arxProxy = new ERC1967Proxy(address(arxImpl), dataArx);
        ARX arx = ARX(address(arxProxy));

        ArxTokenSale saleImpl = new ArxTokenSale();
        bytes memory dataSale = abi.encodeWithSelector(
            ArxTokenSale.initialize.selector, deployer, IERC20(usdc), arx, silo, price
        );
        ERC1967Proxy saleProxy = new ERC1967Proxy(address(saleImpl), dataSale);
        ArxTokenSale sale = ArxTokenSale(address(saleProxy));
        arx.grantRole(arx.MINTER_ROLE(), address(sale));

        // No zap router in minimal setup

        vm.stopBroadcast();
    }
}
