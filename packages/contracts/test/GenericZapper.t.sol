// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GenericZapper} from "../src/zap/GenericZapper.sol";

// Mock contracts
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
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
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
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockSwapRouter {
    mapping(bytes => uint256) public swapRates;
    MockERC20 public outToken;

    constructor(MockERC20 _outToken) {
        outToken = _outToken;
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
        uint256 rate = swapRates[params.path];
        if (rate == 0) {
            // Default 1:1
            amountOut = params.amountIn;
        } else {
            amountOut = (params.amountIn * rate) / 1e18;
        }
        // Mint output token to recipient
        outToken.mint(params.recipient, amountOut);
        return amountOut;
    }
}

contract GenericZapperTest is Test {
    GenericZapper zapper;
    MockWETH9 weth;
    MockERC20 tokenIn;
    MockERC20 tokenOut;
    MockSwapRouter swapRouter;
    address admin = address(0xA11CE);
    address user = address(0xBEEF);
    address recipient = address(0xCAFE);

    function setUp() public {
        vm.startPrank(admin);

        weth = new MockWETH9();
        tokenIn = new MockERC20("InputToken", "IN", 18);
        tokenOut = new MockERC20("OutputToken", "OUT", 6);
        swapRouter = new MockSwapRouter(tokenOut);

        GenericZapper impl = new GenericZapper();
        bytes memory data = abi.encodeWithSelector(
            GenericZapper.initialize.selector,
            admin,
            address(weth),
            address(swapRouter)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), data);
        zapper = GenericZapper(payable(address(proxy)));

        vm.stopPrank();

        // Fund user
        tokenIn.mint(user, 100e18);
        vm.prank(user);
        tokenIn.approve(address(zapper), type(uint256).max);
    }

    function _encodePath(
        address token0,
        address token1
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(token0, uint24(3000), token1);
    }

    function test_ZapERC20_ToTokenOut() public {
        bytes memory path = _encodePath(address(tokenIn), address(tokenOut));
        // Set swap rate: 1 IN = 1 OUT (1e18 IN = 1e6 OUT)
        swapRouter.setSwapRate(path, 1e6);

        uint256 amountIn = 50e18;
        uint256 expectedOut = 50e6;

        vm.prank(user);
        uint256 amountOut = zapper.zap(
            address(tokenIn),
            IERC20(address(tokenOut)),
            amountIn,
            path,
            (expectedOut * 99) / 100,
            recipient,
            block.timestamp + 1,
            address(0),
            0,
            0,
            0,
            bytes32(0),
            bytes32(0)
        );

        assertEq(amountOut, expectedOut);
        assertEq(tokenOut.balanceOf(recipient), expectedOut);
    }

    function test_ZapETH_ToTokenOut() public {
        bytes memory path = _encodePath(address(weth), address(tokenOut));
        // Set swap rate: 1 ETH = 2000 OUT
        swapRouter.setSwapRate(path, 2000e6);

        uint256 ethAmount = 0.025 ether;
        uint256 expectedOut = 50e6;

        vm.deal(user, ethAmount);
        vm.prank(user);
        uint256 amountOut = zapper.zap{value: ethAmount}(
            address(0),
            IERC20(address(tokenOut)),
            ethAmount,
            path,
            (expectedOut * 99) / 100,
            recipient,
            block.timestamp + 1,
            address(0),
            0,
            0,
            0,
            bytes32(0),
            bytes32(0)
        );

        assertEq(amountOut, expectedOut);
        assertEq(tokenOut.balanceOf(recipient), expectedOut);
    }

    function test_RevertWhen_InvalidOutToken() public {
        bytes memory path = _encodePath(address(tokenIn), address(tokenIn)); // Wrong path
        MockERC20 wrongOut = new MockERC20("Wrong", "WRONG", 18);

        vm.prank(user);
        vm.expectRevert(GenericZapper.InvalidOutToken.selector);
        zapper.zap(
            address(tokenIn),
            IERC20(address(wrongOut)),
            10e18,
            path,
            0,
            recipient,
            block.timestamp + 1,
            address(0),
            0,
            0,
            0,
            bytes32(0),
            bytes32(0)
        );
    }

    function test_RevertWhen_ZeroAmount() public {
        bytes memory path = _encodePath(address(tokenIn), address(tokenOut));

        vm.prank(user);
        vm.expectRevert(GenericZapper.ZeroAmount.selector);
        zapper.zap(
            address(tokenIn),
            IERC20(address(tokenOut)),
            0,
            path,
            0,
            recipient,
            block.timestamp + 1,
            address(0),
            0,
            0,
            0,
            bytes32(0),
            bytes32(0)
        );
    }

    function test_RevertWhen_ZeroRecipient() public {
        bytes memory path = _encodePath(address(tokenIn), address(tokenOut));

        vm.prank(user);
        vm.expectRevert(GenericZapper.ZeroAddress.selector);
        zapper.zap(
            address(tokenIn),
            IERC20(address(tokenOut)),
            10e18,
            path,
            0,
            address(0),
            block.timestamp + 1,
            address(0),
            0,
            0,
            0,
            bytes32(0),
            bytes32(0)
        );
    }

    function test_RevertWhen_ETHAmountMismatch() public {
        bytes memory path = _encodePath(address(weth), address(tokenOut));

        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert(GenericZapper.ZeroAmount.selector);
        zapper.zap{value: 0.5 ether}(
            address(0),
            IERC20(address(tokenOut)),
            1 ether,
            path,
            0,
            recipient,
            block.timestamp + 1,
            address(0),
            0,
            0,
            0,
            bytes32(0),
            bytes32(0)
        );
    }

    function test_Pause_Unpause() public {
        vm.prank(admin);
        zapper.pause();
        assertTrue(zapper.paused());

        bytes memory path = _encodePath(address(tokenIn), address(tokenOut));
        vm.prank(user);
        vm.expectRevert();
        zapper.zap(
            address(tokenIn),
            IERC20(address(tokenOut)),
            10e18,
            path,
            0,
            recipient,
            block.timestamp + 1,
            address(0),
            0,
            0,
            0,
            bytes32(0),
            bytes32(0)
        );

        vm.prank(admin);
        zapper.unpause();
        assertFalse(zapper.paused());

        vm.prank(user);
        zapper.zap(
            address(tokenIn),
            IERC20(address(tokenOut)),
            10e18,
            path,
            0,
            recipient,
            block.timestamp + 1,
            address(0),
            0,
            0,
            0,
            bytes32(0),
            bytes32(0)
        );
        assertGt(tokenOut.balanceOf(recipient), 0);
    }

    function test_RevertWhen_Initialize_ZeroAddress() public {
        GenericZapper impl = new GenericZapper();
        bytes memory data = abi.encodeWithSelector(
            GenericZapper.initialize.selector,
            admin,
            address(0), // Zero WETH
            address(swapRouter)
        );
        vm.expectRevert(GenericZapper.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), data);
    }

    function test_Event_Zapped() public {
        bytes memory path = _encodePath(address(tokenIn), address(tokenOut));
        swapRouter.setSwapRate(path, 1e6);

        uint256 amountIn = 10e18;
        uint256 expectedOut = 10e6;

        vm.prank(user);
        // Check event emission - sender is user, recipient is recipient
        vm.expectEmit(true, true, true, true);
        emit GenericZapper.Zapped(
            user, // sender
            recipient, // recipient
            address(tokenIn), // tokenIn
            amountIn, // amountIn
            expectedOut // amountOut
        );
        zapper.zap(
            address(tokenIn),
            IERC20(address(tokenOut)),
            amountIn,
            path,
            (expectedOut * 99) / 100,
            recipient,
            block.timestamp + 1,
            address(0),
            0,
            0,
            0,
            bytes32(0),
            bytes32(0)
        );
    }
}
