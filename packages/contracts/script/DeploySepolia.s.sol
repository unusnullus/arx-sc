// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {ARX} from "../src/token/ARX.sol";
import {ArxTokenSale} from "../src/sale/ArxTokenSale.sol";
import {
    ArxZapRouter,
    IWETH9,
    ISwapRouter,
    IArxTokenSale
} from "../src/zap/ArxZapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "../src/proxy/ERC1967Proxy.sol";

/// @title DeploySepolia
/// @notice Complete deployment script for ARX ecosystem on Sepolia testnet.
/// @dev Deploys ARX token, ArxTokenSale, and ArxZapRouter with full integration.
contract DeploySepolia is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        vm.startBroadcast(pk);

        // Environment variables
        address usdc = vm.envAddress("USDC");
        address weth9 = vm.envAddress("WETH9");
        address swapRouter = vm.envAddress("UNISWAP_V3_SWAPROUTER");
        address uniswapV2Router = vm.envAddress("UNISWAP_V2_ROUTER");
        address silo = vm.envAddress("SILO_TREASURY");
        uint256 price = vm.envUint("ARX_PRICE_USDC_6DP");

        console.log("=== Deploying ARX Ecosystem to Sepolia ===");
        console.log("Deployer:", deployer);
        console.log("USDC:", usdc);
        console.log("WETH9:", weth9);
        console.log("SwapRouter:", swapRouter);
        console.log("UniswapV2Router:", uniswapV2Router);
        console.log("Silo:", silo);
        console.log("Price (6dp):", price);

        // 1. Deploy ARX Token
        console.log("\n--- Deploying ARX Token ---");
        ARX arxImpl = new ARX();
        bytes memory dataArx = abi.encodeWithSelector(
            ARX.initialize.selector,
            deployer,
            address(0), // tokenSale - set later
            uniswapV2Router,
            usdc,
            weth9
        );
        ERC1967Proxy arxProxy = new ERC1967Proxy(address(arxImpl), dataArx);
        ARX arx = ARX(address(arxProxy));
        console.log("ARX Implementation:", address(arxImpl));
        console.log("ARX Proxy:", address(arx));

        // 2. Deploy ArxTokenSale
        console.log("\n--- Deploying ArxTokenSale ---");
        ArxTokenSale saleImpl = new ArxTokenSale();
        bytes memory dataSale = abi.encodeWithSelector(
            ArxTokenSale.initialize.selector,
            deployer,
            IERC20(usdc),
            arx,
            silo,
            price
        );
        ERC1967Proxy saleProxy = new ERC1967Proxy(address(saleImpl), dataSale);
        ArxTokenSale sale = ArxTokenSale(address(saleProxy));
        console.log("Sale Implementation:", address(saleImpl));
        console.log("Sale Proxy:", address(sale));

        // 3. Grant MINTER_ROLE and set tokenSale in ARX
        console.log("\n--- Granting MINTER_ROLE to Sale ---");
        arx.grantRole(arx.MINTER_ROLE(), address(sale));
        console.log("MINTER_ROLE granted to:", address(sale));
        console.log("\n--- Setting TokenSale in ARX ---");
        arx.setTokenSale(address(sale));
        console.log("TokenSale set to:", address(sale));

        // 4. Deploy ArxZapRouter
        console.log("\n--- Deploying ArxZapRouter ---");
        ArxZapRouter zapImpl = new ArxZapRouter();
        bytes memory dataZap = abi.encodeWithSelector(
            ArxZapRouter.initialize.selector,
            deployer,
            IERC20(usdc),
            IWETH9(weth9),
            ISwapRouter(swapRouter)
        );
        ERC1967Proxy zapProxy = new ERC1967Proxy(address(zapImpl), dataZap);
        ArxZapRouter zap = ArxZapRouter(payable(address(zapProxy)));
        console.log("Zap Implementation:", address(zapImpl));
        console.log("Zap Proxy:", address(zap));

        // 5. Wire permissions: connect zap to sale
        console.log("\n--- Wiring Permissions ---");
        zap.setSale(address(sale));
        console.log("Zap sale set to:", address(sale));
        sale.setZapper(address(zap), true);
        console.log("Zap authorized in sale:", address(zap));

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("ARX:", address(arx));
        console.log("ArxTokenSale:", address(sale));
        console.log("ArxZapRouter:", address(zap));
        console.log("\nDeployment complete!");
    }
}
