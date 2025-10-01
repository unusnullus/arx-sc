// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Script } from "forge-std/Script.sol";
import { ARX } from "../src/ARX.sol";
import { ArxTokenSale } from "../src/ArxTokenSale.sol";
import { ArxZapRouter, ISwapRouter, IWETH9, IArxTokenSale } from "../src/ArxZapRouter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

        ARX arx = new ARX(deployer);
        ArxTokenSale sale = new ArxTokenSale(deployer, IERC20(usdc), arx, silo, price);
        arx.grantRole(arx.MINTER_ROLE(), address(sale));

        ArxZapRouter zap =
            new ArxZapRouter(deployer, IERC20(usdc), IWETH9(weth9), ISwapRouter(swapRouter));
        zap.setSale(IArxTokenSale(address(sale)));
        sale.setZapper(address(zap), true);

        vm.stopBroadcast();
    }
}

