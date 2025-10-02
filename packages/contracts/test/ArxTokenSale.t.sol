// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { ARX } from "../src/token/ARX.sol";
import { IARX } from "../src/token/IARX.sol";
import { ArxTokenSale } from "../src/sale/ArxTokenSale.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockUSDC is IERC20 {
    string public name = "MockUSDC";
    string public symbol = "USDC";
    uint8 public decimals = 6;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "allowance");
        allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}

contract ArxTokenSaleTest is Test {
    ARX arx;
    ArxTokenSale sale;
    MockUSDC usdc;
    address admin = address(0xA11CE);
    address silo = address(0x510);
    address buyer = address(0xBEEF);
    uint256 price = 5_000_000; // 5 USDC per ARX (6dp)

    function setUp() public {
        vm.startPrank(admin);
        ARX arxImpl = new ARX();
        bytes memory dataArx = abi.encodeWithSelector(ARX.initialize.selector, admin);
        ERC1967Proxy arxProxy = new ERC1967Proxy(address(arxImpl), dataArx);
        arx = ARX(address(arxProxy));

        usdc = new MockUSDC();

        ArxTokenSale saleImpl = new ArxTokenSale();
        bytes memory dataSale = abi.encodeWithSelector(
            ArxTokenSale.initialize.selector,
            admin,
            IERC20(address(usdc)),
            IARX(address(arx)),
            silo,
            price
        );
        ERC1967Proxy saleProxy = new ERC1967Proxy(address(saleImpl), dataSale);
        sale = ArxTokenSale(address(saleProxy));

        arx.grantRole(arx.MINTER_ROLE(), address(sale));
        vm.stopPrank();

        usdc.mint(buyer, 1000e6);
        vm.prank(buyer);
        usdc.approve(address(sale), type(uint256).max);
    }

    function testBuyWithUSDC_MintsARXAndForwardsToSilo() public {
        vm.prank(buyer);
        sale.buyWithUSDC(50e6); // 50 USDC

        // ARX out = 50 * 1e18 / 5e6 = 10e18
        assertEq(arx.balanceOf(buyer), 10 ether);
        assertEq(usdc.balanceOf(silo), 50e6);
    }

    function testBuyFor_ByZapper() public {
        address zapper = address(0x5A5A);
        vm.prank(admin);
        sale.setZapper(zapper, true);
        vm.startPrank(zapper);
        usdc.mint(zapper, 20e6);
        usdc.approve(address(sale), type(uint256).max);
        sale.buyFor(buyer, 20e6);
        vm.stopPrank();

        assertEq(arx.balanceOf(buyer), (20e6 * 1e18) / price);
        assertEq(usdc.balanceOf(silo), 20e6);
    }

    function testRevertOnlyZapper() public {
        vm.expectRevert(ArxTokenSale.NotZapper.selector);
        sale.buyFor(buyer, 1);
    }

    function testSettersOwnerOnly() public {
        vm.prank(buyer);
        vm.expectRevert();
        sale.setPriceUSDC(1);
        vm.prank(buyer);
        vm.expectRevert();
        sale.setSilo(address(1));
    }
}
