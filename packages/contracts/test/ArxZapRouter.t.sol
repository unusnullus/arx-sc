// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { ArxZapRouter, IWETH9, ISwapRouter, IArxTokenSale } from "../src/ArxZapRouter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

contract MockWETH is IWETH9 {
    string public name = "MockWETH";
    string public symbol = "WETH";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount);
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        (bool ok,) = msg.sender.call{ value: amount }("");
        require(ok);
    }

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
        require(allowed >= amount);
        allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockSale is IArxTokenSale {
    IERC20 public usdc;
    address public lastBuyer;
    uint256 public lastUsdc;

    constructor(IERC20 _usdc) {
        usdc = _usdc;
    }

    function buyFor(address buyer, uint256 usdcAmount) external {
        lastBuyer = buyer;
        lastUsdc = usdcAmount; // pull USDC
        require(usdc.transferFrom(msg.sender, address(this), usdcAmount), "pull");
    }

    function USDC() external view returns (IERC20) {
        return usdc;
    }
}

contract MockRouter is ISwapRouter {
    IERC20 usdc;
    IERC20 tokenSink;

    constructor(IERC20 _usdc) {
        usdc = _usdc;
    }

    function exactInput(ExactInputParams calldata params)
        external
        payable
        returns (uint256 amountOut)
    {
        // naive: take amountIn from msg.sender (already approved), mint equivalent usdc to recipient
        // For tests, mint 2 USDC per 1 tokenIn for determinism
        amountOut = params.amountIn * 2;
        MockUSDC(address(usdc)).mint(params.recipient, amountOut);
    }
}

contract ArxZapRouterTest is Test {
    MockUSDC usdc;
    MockWETH weth;
    MockRouter router;
    MockSale sale;
    ArxZapRouter zap;
    address admin = address(0xA11CE);
    address user = address(0xBEEF);

    function setUp() public {
        usdc = new MockUSDC();
        weth = new MockWETH();
        router = new MockRouter(IERC20(address(usdc)));
        sale = new MockSale(IERC20(address(usdc)));
        vm.startPrank(admin);
        zap = new ArxZapRouter(
            admin, IERC20(address(usdc)), IWETH9(address(weth)), ISwapRouter(address(router))
        );
        zap.setSale(IArxTokenSale(address(sale)));
        vm.stopPrank();
        vm.deal(user, 100 ether);
    }

    function testZapETHAndBuy() public {
        vm.prank(user);
        zap.zapETHAndBuy{ value: 1 ether }(hex"", 1, user, block.timestamp + 1000);
        // Router mints 2 USDC per 1 WETH (1e18 -> 2e18) but USDC 6dp in mock, keeping units abstract; ensure sale registered some amount
        assertGt(sale.lastUsdc(), 0);
        assertEq(sale.lastBuyer(), user);
    }
}
