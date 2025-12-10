// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArxZapRouter} from "../src/zap/ArxZapRouter.sol";
import {ArxTokenSale} from "../src/sale/ArxTokenSale.sol";
import {ARX} from "../src/token/ARX.sol";
import {IARX} from "../src/token/IARX.sol";

// Mock contracts
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

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
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

contract MockWETH9 is IERC20 {
    string public name = "WETH";
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
        require(balanceOf[msg.sender] >= amount, "insufficient balance");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        payable(msg.sender).transfer(amount);
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

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "allowance");
        allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockSwapRouter {
    mapping(bytes => uint256) public swapRates; // path => output amount multiplier (1e18 = 1:1)
    address public lastRecipient;
    uint256 public lastAmountIn;
    MockUSDC public usdc;

    constructor(MockUSDC _usdc) {
        usdc = _usdc;
    }

    function setSwapRate(bytes calldata path, uint256 rate) external {
        swapRates[path] = rate;
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(
        ExactInputParams calldata params
    ) external payable returns (uint256 amountOut) {
        lastRecipient = params.recipient;
        lastAmountIn = params.amountIn;
        uint256 rate = swapRates[params.path];
        if (rate == 0) {
            // Default 1:1 for USDC
            amountOut = params.amountIn;
        } else {
            amountOut = (params.amountIn * rate) / 1e18;
        }
        // Mint USDC to recipient (simulating swap output)
        usdc.mint(params.recipient, amountOut);
        return amountOut;
    }
}

contract MockERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
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

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
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

contract ArxZapRouterTest is Test {
    ArxZapRouter router;
    ArxTokenSale sale;
    ARX arx;
    MockUSDC usdc;
    MockWETH9 weth;
    MockSwapRouter swapRouter;
    address admin = address(0xA11CE);
    address silo = address(0x510);
    address buyer = address(0xBEEF);
    uint256 price = 5_000_000; // 5 USDC per ARX

    function setUp() public {
        vm.startPrank(admin);

        // Deploy ARX
        ARX arxImpl = new ARX();
        bytes memory dataArx = abi.encodeWithSelector(
            ARX.initialize.selector,
            admin,
            address(0), // tokenSale
            address(0), // uniswapRouter
            address(0), // usdcToken
            address(0)  // wethToken
        );
        ERC1967Proxy arxProxy = new ERC1967Proxy(address(arxImpl), dataArx);
        arx = ARX(address(arxProxy));

        // Deploy mocks
        usdc = new MockUSDC();
        weth = new MockWETH9();
        swapRouter = new MockSwapRouter(usdc);

        // Deploy sale
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

        // Deploy router
        ArxZapRouter routerImpl = new ArxZapRouter();
        bytes memory dataRouter = abi.encodeWithSelector(
            ArxZapRouter.initialize.selector,
            admin,
            IERC20(address(usdc)),
            address(weth),
            address(swapRouter)
        );
        ERC1967Proxy routerProxy = new ERC1967Proxy(
            address(routerImpl),
            dataRouter
        );
        router = ArxZapRouter(payable(address(routerProxy)));

        router.setSale(address(sale));
        sale.setZapper(address(router), true);
        vm.stopPrank();

        // Fund buyer
        usdc.mint(buyer, 1000e6);
        vm.prank(buyer);
        usdc.approve(address(router), type(uint256).max);
    }

    function _encodePath(
        address token0,
        address token1
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(token0, uint24(3000), token1);
    }

    function test_ZapUSDC_DirectPurchase() public {
        bytes memory path = _encodePath(address(usdc), address(usdc)); // Not used for USDC
        uint256 usdcAmount = 50e6;

        vm.prank(buyer);
        router.zapAndBuy(
            address(usdc),
            usdcAmount,
            path,
            0,
            buyer,
            block.timestamp + 1
        );

        // ARX out = 50 * 10^6 / 5e6 = 10 * 10^6
        assertEq(arx.balanceOf(buyer), 10e6);
        assertEq(usdc.balanceOf(silo), usdcAmount);
    }

    function test_ZapERC20_ToUSDC() public {
        MockERC20 tokenIn = new MockERC20("TestToken", "TEST", 18);
        tokenIn.mint(buyer, 100e18);
        vm.prank(buyer);
        tokenIn.approve(address(router), type(uint256).max);

        bytes memory path = _encodePath(address(tokenIn), address(usdc));
        // Set swap rate: 1 TEST = 1 USDC (1e18 TEST = 1e6 USDC)
        // Rate is in 1e18 format: 1e6 means 1e6/1e18 = 1e-12 USDC per TEST
        // For 50e18 TEST, we want 50e6 USDC, so rate should be 1e6 * 1e18 / 1e18 = 1e6
        // But we need to account for decimals: 1e18 TEST -> 1e6 USDC
        // So rate = 1e6 * 1e18 / 1e18 = 1e6 (but this is wrong)
        // Actually: amountOut = amountIn * rate / 1e18
        // For 50e18 TEST -> 50e6 USDC: 50e6 = 50e18 * rate / 1e18
        // rate = 50e6 * 1e18 / 50e18 = 1e6
        swapRouter.setSwapRate(path, 1e6);

        uint256 tokenAmount = 50e18;
        uint256 expectedUSDC = 50e6; // 1:1 rate

        vm.prank(buyer);
        router.zapAndBuy(
            address(tokenIn),
            tokenAmount,
            path,
            (expectedUSDC * 99) / 100,
            buyer,
            block.timestamp + 1
        );

        // Should receive ARX based on USDC amount
        assertGt(arx.balanceOf(buyer), 0);
    }

    function test_ZapETH_ToUSDC() public {
        bytes memory path = _encodePath(address(weth), address(usdc));
        // Set swap rate: 1 ETH = 2000 USDC
        // amountOut = amountIn * rate / 1e18
        // For 0.025 ETH (25e15 wei) -> 50e6 USDC: 50e6 = 25e15 * rate / 1e18
        // rate = 50e6 * 1e18 / 25e15 = 2000e6
        swapRouter.setSwapRate(path, 2000e6);

        uint256 ethAmount = 0.025 ether; // 0.025 ETH
        uint256 expectedUSDC = 50e6; // 2000 * 0.025 = 50 USDC

        vm.deal(buyer, ethAmount);
        vm.prank(buyer);
        router.zapAndBuy{value: ethAmount}(
            address(0),
            ethAmount,
            path,
            (expectedUSDC * 99) / 100,
            buyer,
            block.timestamp + 1
        );

        assertGt(arx.balanceOf(buyer), 0);
    }

    function test_RevertWhen_InvalidUSDCPath() public {
        MockERC20 tokenIn = new MockERC20("TestToken", "TEST", 18);
        tokenIn.mint(buyer, 100e18);
        vm.prank(buyer);
        tokenIn.approve(address(router), type(uint256).max);

        // Path ends in wrong token
        bytes memory path = _encodePath(address(tokenIn), address(tokenIn));

        vm.prank(buyer);
        vm.expectRevert(ArxZapRouter.InvalidUSDCPath.selector);
        router.zapAndBuy(
            address(tokenIn),
            10e18,
            path,
            0,
            buyer,
            block.timestamp + 1
        );
    }

    function test_RevertWhen_ZeroAmount() public {
        bytes memory path = _encodePath(address(usdc), address(usdc));

        vm.prank(buyer);
        vm.expectRevert(ArxZapRouter.ZeroAmount.selector);
        router.zapAndBuy(address(usdc), 0, path, 0, buyer, block.timestamp + 1);
    }

    function test_RevertWhen_ETHAmountMismatch() public {
        bytes memory path = _encodePath(address(weth), address(usdc));

        vm.deal(buyer, 1 ether);
        vm.prank(buyer);
        vm.expectRevert(ArxZapRouter.ZeroAmount.selector);
        router.zapAndBuy{value: 0.5 ether}(
            address(0),
            1 ether,
            path,
            0,
            buyer,
            block.timestamp + 1
        );
    }

    function test_Pause_Unpause() public {
        vm.prank(admin);
        router.pause();
        assertTrue(router.paused());

        bytes memory path = _encodePath(address(usdc), address(usdc));
        vm.prank(buyer);
        vm.expectRevert();
        router.zapAndBuy(
            address(usdc),
            10e6,
            path,
            0,
            buyer,
            block.timestamp + 1
        );

        vm.prank(admin);
        router.unpause();
        assertFalse(router.paused());

        vm.prank(buyer);
        router.zapAndBuy(
            address(usdc),
            10e6,
            path,
            0,
            buyer,
            block.timestamp + 1
        );
        assertGt(arx.balanceOf(buyer), 0);
    }

    function test_SetSale() public {
        // Deploy new sale
        ArxTokenSale newSaleImpl = new ArxTokenSale();
        bytes memory dataSale = abi.encodeWithSelector(
            ArxTokenSale.initialize.selector,
            admin,
            IERC20(address(usdc)),
            IARX(address(arx)),
            silo,
            price
        );
        ERC1967Proxy newSaleProxy = new ERC1967Proxy(
            address(newSaleImpl),
            dataSale
        );
        ArxTokenSale newSale = ArxTokenSale(address(newSaleProxy));

        vm.startPrank(admin);
        arx.grantRole(arx.MINTER_ROLE(), address(newSale));
        newSale.setZapper(address(router), true);
        router.setSale(address(newSale));
        vm.stopPrank();

        bytes memory path = _encodePath(address(usdc), address(usdc));
        vm.prank(buyer);
        router.zapAndBuy(
            address(usdc),
            10e6,
            path,
            0,
            buyer,
            block.timestamp + 1
        );

        assertGt(arx.balanceOf(buyer), 0);
    }

    function test_RevertWhen_SetSale_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(ArxZapRouter.ZeroAddress.selector);
        router.setSale(address(0));
    }

    function test_RevertWhen_Initialize_ZeroAddress() public {
        ArxZapRouter impl = new ArxZapRouter();
        bytes memory data = abi.encodeWithSelector(
            ArxZapRouter.initialize.selector,
            admin,
            IERC20(address(0)), // Zero USDC
            address(weth),
            address(swapRouter)
        );
        vm.expectRevert(ArxZapRouter.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), data);
    }
}
