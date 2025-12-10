// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {ARX} from "../src/token/ARX.sol";
import {ArxTokenSale} from "../src/sale/ArxTokenSale.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IARX} from "../src/token/IARX.sol";
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
}

contract MockWETH {
    string public name = "WETH";
    string public symbol = "WETH";
    uint8 public decimals = 18;
}

contract ARXTest is Test {
    ARX token;
    address admin = address(0xA11CE);
    address minter = address(0xBEEF);
    address user = address(0xCAFE);

    function setUp() public {
        ARX impl = new ARX();
        bytes memory data = abi.encodeWithSelector(
            ARX.initialize.selector,
            admin,
            address(0), // tokenSale
            address(0), // uniswapRouter
            address(0), // usdcToken
            address(0)  // wethToken
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), data);
        token = ARX(address(proxy));
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();
    }

    function testMintByMinter() public {
        vm.prank(minter);
        token.mint(user, 1_000_000); // 1 ARX (6 decimals)
        assertEq(token.balanceOf(user), 1_000_000);
    }

    function test_RevertWhen_NonMinterMints() public {
        vm.expectRevert();
        token.mint(user, 1_000_000);
    }

    function test_RevertWhen_InitializeWithZeroAdmin() public {
        ARX impl = new ARX();
        bytes memory data = abi.encodeWithSelector(
            ARX.initialize.selector,
            address(0), // admin
            address(0), // tokenSale
            address(0), // uniswapRouter
            address(0), // usdcToken
            address(0)  // wethToken
        );
        vm.expectRevert(ARX.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), data);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.prank(minter);
        vm.expectRevert(ARX.ZeroAddress.selector);
        token.mint(address(0), 1 ether);
    }

    function test_RevertWhen_MintZeroAmount() public {
        vm.prank(minter);
        vm.expectRevert(ARX.ZeroAmount.selector);
        token.mint(user, 0);
    }

    function test_RevertWhen_MintExceedsMaxSupply() public {
        uint256 maxSupply = token.MAX_SUPPLY();
        vm.startPrank(minter);
        token.mint(user, maxSupply); // Mint exactly max supply
        vm.expectRevert(ARX.MaxSupplyExceeded.selector);
        token.mint(user, 1); // Try to mint 1 more
        vm.stopPrank();
    }

    function test_TotalMintedTracking() public {
        vm.startPrank(minter);
        token.mint(user, 100_000_000); // 100 ARX
        assertEq(token.totalMinted(), 100_000_000);
        token.mint(user, 50_000_000); // 50 ARX
        assertEq(token.totalMinted(), 150_000_000);
        vm.stopPrank();
    }

    function test_BurnDoesNotAffectTotalMinted() public {
        vm.prank(minter);
        token.mint(user, 100_000_000);
        uint256 mintedBefore = token.totalMinted();

        vm.prank(user);
        token.burn(50_000_000);

        // totalMinted should not change after burn
        assertEq(token.totalMinted(), mintedBefore);
    }
}

contract ARXExchangeRateTest is Test {
    ARX arx;
    ArxTokenSale sale;
    MockUSDC usdc;
    MockWETH weth;
    MockUniswapV2Router router;
    address admin = address(0xA11CE);
    address silo = address(0x510);
    uint256 price = 5_000_000; // 5 USDC per ARX (6dp)

    function setUp() public {
        // Deploy ARX
        // Deploy mocks first
        usdc = new MockUSDC();
        weth = new MockWETH();
        router = new MockUniswapV2Router();

        // Deploy ARX (with optional price params - will set sale later)
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
        vm.startPrank(admin);
        arx.grantRole(arx.MINTER_ROLE(), address(sale));
        arx.setTokenSale(address(sale));
        vm.stopPrank();
    }

    /// @notice Test that exchange rate calculation matches the formula in ArxTokenSale.buyWithUSDC
    function test_ExchangeRateMatchesSaleFormula() public {
        uint256 usdcAmount = 50e6; // 50 USDC

        // Calculate expected ARX using the same formula as in ArxTokenSale
        uint8 arxDecimals = sale.arxDecimals();
        uint256 expectedArx = (usdcAmount * (10 ** uint256(arxDecimals))) /
            price;

        // Get ARX amount from exchange rate function
        uint256 actualArx = arx.getTokenToArxExchangeRate(
            address(usdc),
            usdcAmount
        );

        // They should match exactly
        assertEq(
            actualArx,
            expectedArx,
            "Exchange rate should match sale formula"
        );
    }

    /// @notice Test that exchange rate works for different USDC amounts
    function test_ExchangeRateForDifferentAmounts() public {
        uint256[] memory usdcAmounts = new uint256[](4);
        usdcAmounts[0] = 10e6; // 10 USDC
        usdcAmounts[1] = 50e6; // 50 USDC
        usdcAmounts[2] = 100e6; // 100 USDC
        usdcAmounts[3] = 1000e6; // 1000 USDC

        uint8 arxDecimals = sale.arxDecimals();

        for (uint256 i = 0; i < usdcAmounts.length; i++) {
            uint256 expectedArx = (usdcAmounts[i] *
                (10 ** uint256(arxDecimals))) / price;
            uint256 actualArx = arx.getTokenToArxExchangeRate(
                address(usdc),
                usdcAmounts[i]
            );
            assertEq(
                actualArx,
                expectedArx,
                "Exchange rate should match for all amounts"
            );
        }
    }

    /// @notice Test getTokenToArxExchangeRate with non-USDC token via Uniswap
    function test_GetTokenToArxExchangeRate_WithOtherToken() public {
        MockERC20 otherToken = new MockERC20("OtherToken", "OTK", 18);
        otherToken.mint(address(this), 100e18);
        
        // Set exchange rate: 1 OTK = 2 USDC (2e6 USDC per 1e18 OTK)
        // Rate in 1e18 format: 2e6 * 1e18 / 1e18 = 2e6
        address[] memory path = new address[](2);
        path[0] = address(otherToken);
        path[1] = address(usdc);
        router.setExchangeRate(address(otherToken), address(usdc), 2e6);
        
        uint256 tokenAmount = 25e18; // 25 OTK
        uint256 expectedUSDC = 50e6; // 25 * 2 = 50 USDC
        uint256 expectedARX = (expectedUSDC * (10 ** sale.arxDecimals())) / price;
        
        uint256 actualARX = arx.getTokenToArxExchangeRate(
            address(otherToken),
            tokenAmount
        );
        
        assertEq(actualARX, expectedARX);
    }

    /// @notice Test getTokenToArxExchangeRate with ETH (address(0))
    function test_GetTokenToArxExchangeRate_WithETH() public {
        // Set exchange rate: 1 WETH = 2000 USDC
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(usdc);
        router.setExchangeRate(address(weth), address(usdc), 2000e6);
        
        uint256 ethAmount = 0.025e18; // 0.025 ETH
        uint256 expectedUSDC = 50e6; // 0.025 * 2000 = 50 USDC
        uint256 expectedARX = (expectedUSDC * (10 ** sale.arxDecimals())) / price;
        
        uint256 actualARX = arx.getTokenToArxExchangeRate(
            address(0), // ETH
            ethAmount
        );
        
        assertEq(actualARX, expectedARX);
    }

    /// @notice Test getArxPriceInToken with USDC
    function test_GetArxPriceInToken_WithUSDC() public {
        uint256 arxAmount = 10e6; // 10 ARX
        uint256 expectedUSDC = (arxAmount * price) / (10 ** sale.arxDecimals());
        
        uint256 actualUSDC = arx.getArxPriceInToken(address(usdc), arxAmount);
        
        assertEq(actualUSDC, expectedUSDC);
    }

    /// @notice Test getArxPriceInToken with other token via Uniswap
    function test_GetArxPriceInToken_WithOtherToken() public {
        MockERC20 otherToken = new MockERC20("OtherToken", "OTK", 18);
        
        // Set exchange rate: 1 USDC = 0.5 OTK (1e6 USDC = 0.5e18 OTK)
        // Rate in 1e18 format: 0.5e18 * 1e18 / 1e6 = 0.5e30, but we need to account for decimals
        // Actually: amountOut = amountIn * rate / 1e18
        // For 1e6 USDC -> 0.5e18 OTK: 0.5e18 = 1e6 * rate / 1e18
        // rate = 0.5e18 * 1e18 / 1e6 = 0.5e30
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(otherToken);
        router.setExchangeRate(address(usdc), address(otherToken), 0.5e30);
        
        uint256 arxAmount = 10e6; // 10 ARX
        uint256 usdcValue = (arxAmount * price) / (10 ** sale.arxDecimals());
        uint256 expectedOTK = (usdcValue * 0.5e30) / 1e18;
        
        uint256 actualOTK = arx.getArxPriceInToken(address(otherToken), arxAmount);
        
        assertEq(actualOTK, expectedOTK);
    }

    /// @notice Test getArxPriceInToken with ETH
    function test_GetArxPriceInToken_WithETH() public {
        // Set exchange rate: 1 USDC = 0.0005 WETH
        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(weth);
        router.setExchangeRate(address(usdc), address(weth), 0.0005e18);
        
        uint256 arxAmount = 10e6; // 10 ARX
        uint256 usdcValue = (arxAmount * price) / (10 ** sale.arxDecimals());
        uint256 expectedWETH = (usdcValue * 0.0005e18) / 1e18;
        
        uint256 actualWETH = arx.getArxPriceInToken(address(0), arxAmount);
        
        assertEq(actualWETH, expectedWETH);
    }

    /// @notice Test setters
    function test_SetTokenSale() public {
        ArxTokenSale newSaleImpl = new ArxTokenSale();
        bytes memory dataSale = abi.encodeWithSelector(
            ArxTokenSale.initialize.selector,
            admin,
            IERC20(address(usdc)),
            IARX(address(arx)),
            address(0x999),
            price
        );
        ERC1967Proxy newSaleProxy = new ERC1967Proxy(address(newSaleImpl), dataSale);
        ArxTokenSale newSale = ArxTokenSale(address(newSaleProxy));
        
        vm.startPrank(admin);
        arx.grantRole(arx.MINTER_ROLE(), address(newSale));
        arx.setTokenSale(address(newSale));
        vm.stopPrank();
        
        assertEq(address(arx.tokenSale()), address(newSale));
    }

    function test_SetUniswapRouter() public {
        MockUniswapV2Router newRouter = new MockUniswapV2Router();
        
        vm.prank(admin);
        arx.setUniswapRouter(address(newRouter));
        
        assertEq(address(arx.uniswapRouter()), address(newRouter));
    }

    function test_SetUsdcToken() public {
        MockUSDC newUsdc = new MockUSDC();
        
        vm.prank(admin);
        arx.setUsdcToken(address(newUsdc));
        
        assertEq(address(arx.usdcToken()), address(newUsdc));
    }

    function test_SetWethToken() public {
        MockWETH newWeth = new MockWETH();
        
        vm.prank(admin);
        arx.setWethToken(address(newWeth));
        
        assertEq(address(arx.wethToken()), address(newWeth));
    }

    /// @notice Test revert when setters called with zero address
    function test_RevertWhen_SetTokenSale_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(ARX.InvalidAddress.selector);
        arx.setTokenSale(address(0));
    }

    function test_RevertWhen_SetUniswapRouter_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(ARX.InvalidAddress.selector);
        arx.setUniswapRouter(address(0));
    }

    function test_RevertWhen_SetUsdcToken_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(ARX.InvalidAddress.selector);
        arx.setUsdcToken(address(0));
    }

    function test_RevertWhen_SetWethToken_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(ARX.InvalidAddress.selector);
        arx.setWethToken(address(0));
    }

    /// @notice Test revert when price contracts not initialized
    function test_RevertWhen_GetTokenToArxExchangeRate_NotInitialized() public {
        ARX arxImpl = new ARX();
        bytes memory dataArx = abi.encodeWithSelector(
            ARX.initialize.selector,
            admin,
            address(0), // tokenSale not set
            address(router),
            address(usdc),
            address(weth)
        );
        ERC1967Proxy arxProxy = new ERC1967Proxy(address(arxImpl), dataArx);
        ARX uninitializedArx = ARX(address(arxProxy));
        
        vm.expectRevert(ARX.PriceContractsNotInitialized.selector);
        uninitializedArx.getTokenToArxExchangeRate(address(usdc), 1e6);
    }

    function test_RevertWhen_GetArxPriceInToken_NotInitialized() public {
        ARX arxImpl = new ARX();
        bytes memory dataArx = abi.encodeWithSelector(
            ARX.initialize.selector,
            admin,
            address(0), // tokenSale not set
            address(router),
            address(usdc),
            address(weth)
        );
        ERC1967Proxy arxProxy = new ERC1967Proxy(address(arxImpl), dataArx);
        ARX uninitializedArx = ARX(address(arxProxy));
        
        vm.expectRevert(ARX.PriceContractsNotInitialized.selector);
        uninitializedArx.getArxPriceInToken(address(usdc), 1e6);
    }

    /// @notice Test revert when amount is zero
    function test_RevertWhen_GetTokenToArxExchangeRate_ZeroAmount() public {
        vm.expectRevert(ARX.InvalidAmount.selector);
        arx.getTokenToArxExchangeRate(address(usdc), 0);
    }

    function test_RevertWhen_GetArxPriceInToken_ZeroAmount() public {
        vm.expectRevert(ARX.InvalidAmount.selector);
        arx.getArxPriceInToken(address(usdc), 0);
    }
}

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    mapping(address => uint256) public balanceOf;
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
}
