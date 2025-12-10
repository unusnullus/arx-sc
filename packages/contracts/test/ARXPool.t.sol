// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ARX} from "../src/token/ARX.sol";
import {IARX} from "../src/token/IARX.sol";
import {ArxTokenSale} from "../src/sale/ArxTokenSale.sol";
import {ARXPool} from "../src/pool/ARXPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @notice Mock Uniswap V2 Router for testing
contract MockUniswapV2Router {
    mapping(address => mapping(address => uint256)) public exchangeRates;

    function setExchangeRate(
        address tokenIn,
        address tokenOut,
        uint256 rate
    ) external {
        exchangeRates[tokenIn][tokenOut] = rate;
    }

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i = 0; i < path.length - 1; i++) {
            uint256 rate = exchangeRates[path[i]][path[i + 1]];
            if (rate == 0) {
                // Default 1:1 if rate not set
                amounts[i + 1] = amountIn;
            } else {
                amounts[i + 1] = (amountIn * rate) / 1e18;
            }
        }
    }
}

contract MockUSDC {
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

contract MockWETH {
    string public name = "WETH";
    string public symbol = "WETH";
    uint8 public decimals = 18;
}

contract ARXPoolTest is Test {
    ARX arx;
    ARXPool pool;
    ArxTokenSale sale;
    MockUSDC usdc;
    MockWETH weth;
    MockUniswapV2Router router;
    address admin = address(0xA11CE);
    address silo = address(0x510);
    address user = address(0xBEEF);
    address lpProvider = address(0xCAFE);
    uint256 price = 5_000_000; // 5 USDC per 1 ARX (6 decimals)

    function setUp() public {
        // Deploy mocks first
        usdc = new MockUSDC();
        weth = new MockWETH();
        router = new MockUniswapV2Router();

        // Deploy ARX (with optional price params - will set sale later)
        vm.startPrank(admin);
        ARX arxImpl = new ARX();
        bytes memory dataArx = abi.encodeWithSelector(
            ARX.initialize.selector,
            admin,
            address(0), // tokenSale - set later
            address(router),
            address(usdc),
            address(weth)
        );
        ERC1967Proxy arxProxy = new ERC1967Proxy(address(arxImpl), dataArx);
        arx = ARX(address(arxProxy));

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

        // Grant MINTER_ROLE and set tokenSale
        arx.grantRole(arx.MINTER_ROLE(), address(sale));
        arx.setTokenSale(address(sale));

        // Deploy pool
        ARXPool poolImpl = new ARXPool();
        bytes memory dataPool = abi.encodeWithSelector(
            ARXPool.initialize.selector,
            address(arx),
            address(usdc),
            admin
        );
        ERC1967Proxy poolProxy = new ERC1967Proxy(address(poolImpl), dataPool);
        pool = ARXPool(address(poolProxy));
        vm.stopPrank();

        // Setup user balances
        usdc.mint(user, 10000e6);
        usdc.mint(lpProvider, 10000e6);
        vm.prank(user);
        usdc.approve(address(pool), type(uint256).max);
        vm.prank(lpProvider);
        usdc.approve(address(pool), type(uint256).max);

        // Mint ARX to users
        vm.startPrank(admin);
        arx.grantRole(arx.MINTER_ROLE(), address(this));
        vm.stopPrank();
        arx.mint(user, 10000e6);
        arx.mint(lpProvider, 10000e6);
        vm.prank(user);
        arx.approve(address(pool), type(uint256).max);
        vm.prank(lpProvider);
        arx.approve(address(pool), type(uint256).max);
    }

    // ---------- Initialization Tests ----------

    function test_Initialize() public {
        assertEq(address(pool.arx()), address(arx));
        assertEq(address(pool.usdc()), address(usdc));
        assertEq(pool.owner(), admin);
        assertEq(pool.swapFee(), 50); // 0.5% default
        assertEq(pool.decimals(), 6);
        assertEq(pool.name(), "ARX/USDC LP");
        assertEq(pool.symbol(), "ARX-USDC-LP");
    }

    function test_RevertWhen_InitializeWithZeroAddress() public {
        ARXPool impl = new ARXPool();
        bytes memory data = abi.encodeWithSelector(
            ARXPool.initialize.selector,
            address(0),
            address(usdc),
            admin
        );
        vm.expectRevert(ARXPool.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), data);
    }

    // ---------- Reserves Tests ----------

    function test_GetReserves_EmptyPool() public {
        (uint256 reserveARX, uint256 reserveUSDC) = pool.getReserves();
        assertEq(reserveARX, 0);
        assertEq(reserveUSDC, 0);
    }

    // ---------- Pricing Tests ----------

    function test_GetAdjustedPrice_ARXToUSDC() public view {
        uint256 arxPrice = pool.getAdjustedPrice(address(arx), address(usdc));
        // Should be 5 USDC per 1 ARX (price = 5_000_000 for 1e6 ARX)
        assertEq(arxPrice, 5_000_000);
    }

    function test_GetAdjustedPrice_USDCToARX() public view {
        uint256 usdcPrice = pool.getAdjustedPrice(address(usdc), address(arx));
        // Inverse: 1 USDC = 0.2 ARX = 200_000 (6 decimals)
        assertEq(usdcPrice, 200_000);
    }

    function test_RevertWhen_GetAdjustedPrice_InvalidPair() public {
        vm.expectRevert(ARXPool.InvalidPair.selector);
        pool.getAdjustedPrice(address(arx), address(arx));
    }

    // ---------- Add Liquidity Tests ----------

    function test_AddLiquidity_FirstLP_SingleSided_ARX() public {
        uint256 arxAmount = 1000e6; // 1000 ARX

        vm.prank(lpProvider);
        (uint256 arxAdded, uint256 usdcAdded, uint256 lpMinted) = pool
            .addLiquidity(arxAmount, 0);

        assertEq(arxAdded, arxAmount);
        assertEq(usdcAdded, 0);
        // LP should equal USD value: 1000 ARX * 5 USDC = 5000 USDC
        assertEq(lpMinted, 5000e6);
        assertEq(pool.balanceOf(lpProvider), 5000e6);
        assertEq(arx.balanceOf(address(pool)), arxAmount);
    }

    function test_AddLiquidity_FirstLP_SingleSided_USDC() public {
        uint256 usdcAmount = 5000e6; // 5000 USDC

        vm.prank(lpProvider);
        (uint256 arxAdded, uint256 usdcAdded, uint256 lpMinted) = pool
            .addLiquidity(0, usdcAmount);

        assertEq(arxAdded, 0);
        assertEq(usdcAdded, usdcAmount);
        assertEq(lpMinted, usdcAmount);
        assertEq(pool.balanceOf(lpProvider), usdcAmount);
        assertEq(usdc.balanceOf(address(pool)), usdcAmount);
    }

    function test_AddLiquidity_FirstLP_DualSided() public {
        uint256 arxAmount = 1000e6; // 1000 ARX
        uint256 usdcAmount = 5000e6; // 5000 USDC (matches 1:5 ratio)

        vm.prank(lpProvider);
        (uint256 arxAdded, uint256 usdcAdded, uint256 lpMinted) = pool
            .addLiquidity(arxAmount, usdcAmount);

        assertEq(arxAdded, arxAmount);
        assertEq(usdcAdded, usdcAmount);
        // Total USD value: 5000 + 5000 = 10000 USDC
        assertEq(lpMinted, 10000e6);
    }

    function test_AddLiquidity_DualSided_TrimsToRatio() public {
        // First LP
        vm.prank(lpProvider);
        pool.addLiquidity(1000e6, 5000e6);

        // Second LP with excess USDC
        uint256 arxAmount = 1000e6;
        uint256 usdcAmount = 10000e6; // More than needed

        vm.prank(user);
        (uint256 arxAdded, uint256 usdcAdded, uint256 lpMinted) = pool
            .addLiquidity(arxAmount, usdcAmount);

        // Should trim to 5000 USDC (matching ARX amount)
        assertEq(arxAdded, arxAmount);
        assertEq(usdcAdded, 5000e6);
        assertGt(lpMinted, 0);
    }

    function test_AddLiquidity_SecondLP_SingleSided() public {
        // First LP
        vm.prank(lpProvider);
        pool.addLiquidity(1000e6, 5000e6);

        // Second LP with ARX only
        uint256 arxAmount = 500e6; // 500 ARX = 2500 USDC value

        vm.prank(user);
        (uint256 arxAdded, uint256 usdcAdded, uint256 lpMinted) = pool
            .addLiquidity(arxAmount, 0);

        assertEq(arxAdded, arxAmount);
        assertEq(usdcAdded, 0);
        // Should get proportional LP: 2500 / 10000 * 10000 = 2500
        assertEq(lpMinted, 2500e6);
    }

    function test_RevertWhen_AddLiquidity_ZeroAmounts() public {
        vm.expectRevert(ARXPool.ZeroAmount.selector);
        vm.prank(lpProvider);
        pool.addLiquidity(0, 0);
    }

    // ---------- Remove Liquidity Tests ----------

    function test_RemoveLiquidity() public {
        // Add liquidity
        vm.prank(lpProvider);
        pool.addLiquidity(1000e6, 5000e6);
        uint256 lpBalance = pool.balanceOf(lpProvider);

        // Get balances before removal
        uint256 arxBefore = arx.balanceOf(lpProvider);
        uint256 usdcBefore = usdc.balanceOf(lpProvider);

        // Remove half
        uint256 lpToRemove = lpBalance / 2;
        vm.prank(lpProvider);
        (uint256 arxReturned, uint256 usdcReturned) = pool.removeLiquidity(
            lpToRemove
        );

        assertEq(arxReturned, 500e6); // Half of 1000
        assertEq(usdcReturned, 2500e6); // Half of 5000
        assertEq(arx.balanceOf(lpProvider), arxBefore + arxReturned);
        assertEq(usdc.balanceOf(lpProvider), usdcBefore + usdcReturned);
    }

    function test_RemoveLiquidity_All() public {
        // Add liquidity
        vm.prank(lpProvider);
        pool.addLiquidity(1000e6, 5000e6);
        uint256 lpBalance = pool.balanceOf(lpProvider);

        // Remove all
        vm.prank(lpProvider);
        (uint256 arxReturned, uint256 usdcReturned) = pool.removeLiquidity(
            lpBalance
        );

        assertEq(arxReturned, 1000e6);
        assertEq(usdcReturned, 5000e6);
        assertEq(pool.balanceOf(lpProvider), 0);
    }

    function test_RevertWhen_RemoveLiquidity_ZeroAmount() public {
        vm.expectRevert(ARXPool.ZeroAmount.selector);
        vm.prank(lpProvider);
        pool.removeLiquidity(0);
    }

    function test_RevertWhen_RemoveLiquidity_EmptyPool() public {
        vm.expectRevert(ARXPool.EmptyPool.selector);
        vm.prank(lpProvider);
        pool.removeLiquidity(1e6);
    }

    // ---------- Swap Tests ----------

    function test_SwapExactARXToUSDC() public {
        // Add liquidity
        vm.prank(lpProvider);
        pool.addLiquidity(1000e6, 5000e6);

        // Swap 100 ARX for USDC
        uint256 arxIn = 100e6;
        uint256 minUSDC = 0;

        uint256 usdcBalanceBefore = usdc.balanceOf(user);
        vm.prank(user);
        pool.swapExactARXToUSDC(arxIn, minUSDC);
        uint256 usdcBalanceAfter = usdc.balanceOf(user);

        // 100 ARX * 5 USDC = 500 USDC, minus 0.5% fee = 497.5 USDC
        uint256 expectedOut = (500e6 * 9950) / 10000; // 497.5 USDC
        assertEq(usdcBalanceAfter - usdcBalanceBefore, expectedOut);
    }

    function test_SwapExactUSDCToARX() public {
        // Add liquidity
        vm.prank(lpProvider);
        pool.addLiquidity(1000e6, 5000e6);

        // Swap 100 USDC for ARX
        uint256 usdcIn = 100e6;
        uint256 minARX = 0;

        uint256 arxBalanceBefore = arx.balanceOf(user);
        vm.prank(user);
        pool.swapExactUSDCToARX(usdcIn, minARX);
        uint256 arxBalanceAfter = arx.balanceOf(user);

        // 100 USDC / 5 = 20 ARX, minus 0.5% fee = 19.9 ARX
        uint256 expectedOut = (20e6 * 9950) / 10000; // 19.9 ARX
        assertEq(arxBalanceAfter - arxBalanceBefore, expectedOut);
    }

    function test_SwapExactARXToUSDC_RespectsReserves() public {
        // Add liquidity
        vm.prank(lpProvider);
        pool.addLiquidity(1000e6, 5000e6);

        // Try to swap more than reserves allow
        uint256 arxIn = 2000e6; // More than in pool
        uint256 minUSDC = 0;

        uint256 usdcBalanceBefore = usdc.balanceOf(user);
        vm.prank(user);
        pool.swapExactARXToUSDC(arxIn, minUSDC);
        uint256 usdcBalanceAfter = usdc.balanceOf(user);

        // Should only get what's in reserves (5000 USDC max)
        uint256 usdcReceived = usdcBalanceAfter - usdcBalanceBefore;
        assertEq(usdcReceived, 5000e6); // All reserves
    }

    function test_RevertWhen_SwapExactARXToUSDC_ZeroAmount() public {
        vm.expectRevert(ARXPool.ZeroAmount.selector);
        vm.prank(user);
        pool.swapExactARXToUSDC(0, 0);
    }

    function test_RevertWhen_SwapExactARXToUSDC_Slippage() public {
        // Add liquidity
        vm.prank(lpProvider);
        pool.addLiquidity(1000e6, 5000e6);

        uint256 arxIn = 100e6;
        uint256 minUSDC = 10000e6; // Unrealistic minimum

        vm.expectRevert(ARXPool.Slippage.selector);
        vm.prank(user);
        pool.swapExactARXToUSDC(arxIn, minUSDC);
    }

    // ---------- Preview Tests ----------

    function test_PreviewAddLiquidity_FirstLP() public {
        (uint256 arxToAdd, uint256 usdcToAdd, uint256 lpToMint) = pool
            .previewAddLiquidity(1000e6, 5000e6);

        assertEq(arxToAdd, 1000e6);
        assertEq(usdcToAdd, 5000e6);
        assertEq(lpToMint, 10000e6); // 5000 + 5000
    }

    function test_PreviewAddLiquidity_SecondLP() public {
        // Add first LP
        vm.prank(lpProvider);
        pool.addLiquidity(1000e6, 5000e6);

        // Preview second LP
        (uint256 arxToAdd, uint256 usdcToAdd, uint256 lpToMint) = pool
            .previewAddLiquidity(500e6, 0);

        assertEq(arxToAdd, 500e6);
        assertEq(usdcToAdd, 0);
        assertGt(lpToMint, 0);
    }

    // ---------- Admin Tests ----------

    function test_SetSwapFee() public {
        vm.prank(admin);
        pool.setSwapFee(100); // 1%
        assertEq(pool.swapFee(), 100);
    }

    function test_RevertWhen_SetSwapFee_TooHigh() public {
        vm.expectRevert(ARXPool.FeeTooHigh.selector);
        vm.prank(admin);
        pool.setSwapFee(501); // > 5%
    }

    function test_RevertWhen_SetSwapFee_NotOwner() public {
        vm.expectRevert();
        vm.prank(user);
        pool.setSwapFee(100);
    }

    function test_Pause() public {
        vm.prank(admin);
        pool.pause();
        assertTrue(pool.paused());
    }

    function test_Unpause() public {
        vm.prank(admin);
        pool.pause();
        vm.prank(admin);
        pool.unpause();
        assertFalse(pool.paused());
    }

    function test_RevertWhen_AddLiquidity_WhenPaused() public {
        vm.prank(admin);
        pool.pause();

        vm.expectRevert();
        vm.prank(lpProvider);
        pool.addLiquidity(1000e6, 5000e6);
    }

    function test_RevertWhen_Swap_WhenPaused() public {
        vm.prank(admin);
        pool.pause();

        vm.expectRevert();
        vm.prank(user);
        pool.swapExactARXToUSDC(100e6, 0);
    }

    // ---------- Integration Tests ----------

    function test_FullFlow_AddSwapRemove() public {
        // 1. Add liquidity
        vm.prank(lpProvider);
        pool.addLiquidity(1000e6, 5000e6);
        uint256 lpBalance = pool.balanceOf(lpProvider);

        // 2. Swap
        vm.prank(user);
        pool.swapExactARXToUSDC(100e6, 0);

        // 3. Remove liquidity
        vm.prank(lpProvider);
        pool.removeLiquidity(lpBalance);

        // LP provider should get back tokens (minus what was swapped)
        assertGt(arx.balanceOf(lpProvider), 0);
        assertGt(usdc.balanceOf(lpProvider), 0);
    }

    function test_MultipleLPs_ProportionalShares() public {
        // First LP
        vm.prank(lpProvider);
        pool.addLiquidity(1000e6, 5000e6);
        uint256 lp1 = pool.balanceOf(lpProvider);

        // Second LP
        vm.prank(user);
        pool.addLiquidity(500e6, 2500e6);
        uint256 lp2 = pool.balanceOf(user);

        // Second LP should get proportional shares
        // Total pool: 1500 ARX + 7500 USDC = 15000 USD value
        // Second LP: 500 ARX + 2500 USDC = 5000 USD value
        // Ratio: 5000 / 15000 = 1/3
        assertApproxEqRel(lp2, lp1 / 2, 0.01e18); // Approximately half
    }
}
