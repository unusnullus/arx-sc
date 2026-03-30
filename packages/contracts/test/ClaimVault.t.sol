// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ClaimVault, ISwapRouterV3 } from "../src/claimable/ClaimVault.sol";
import { MockUSDC } from "../src/mocks/MockUSDC.sol";
import { MockERC20 } from "../src/mocks/MockERC20.sol";

/// @notice Reverts if `exactInput` is called — USDC/USDT paths must not hit Uniswap.
contract RevertingSwapRouter is ISwapRouterV3 {
    function exactInput(ExactInputParams calldata) external payable returns (uint256) {
        revert("swap router should not be called for USDC/USDT");
    }
}

/// @notice Minimal router: pulls `tokenIn` from vault, mints USDC to `recipient` (same pattern as GenericZapper tests).
contract MockSwapRouterV3 is ISwapRouterV3 {
    MockUSDC public immutable usdc;

    constructor(MockUSDC usdc_) {
        usdc = usdc_;
    }

    function exactInput(ExactInputParams calldata params)
        external
        payable
        returns (uint256 amountOut)
    {
        bytes calldata path = params.path;
        require(path.length >= 20, "path");
        address tokenIn;
        assembly {
            tokenIn := shr(96, calldataload(path.offset))
        }
        IERC20(tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        // Enough USDC to satisfy FEE_6_DECIMALS + 1 minOut and leave escrow remainder
        amountOut = 10 * 1e6;
        require(amountOut >= params.amountOutMinimum, "minOut");
        usdc.mint(params.recipient, amountOut);
        return amountOut;
    }
}

contract ClaimVaultTest is Test {
    ClaimVault vault;
    MockUSDC usdc;
    MockERC20 usdt;
    MockERC20 weth;

    address sender = address(0x1);
    address receiver = address(0x2);
    address other = address(0x3);

    bytes32 constant SECRET_PREIMAGE = keccak256("my-secret");
    bytes32 hashlock;

    function setUp() public {
        usdc = new MockUSDC();
        usdt = new MockERC20("MockUSDT", "USDT", 6);
        weth = new MockERC20("MockWETH", "WETH", 18);

        // swapRouter is not used in these USDC-only tests, but constructor requires non-zero.
        vault = new ClaimVault(
            IERC20(address(usdc)),
            IERC20(address(usdt)),
            IERC20(address(weth)),
            ISwapRouterV3(address(0xBEEF))
        );

        usdc.mint(sender, 1_000_000e6);
        hashlock = keccak256(abi.encode(SECRET_PREIMAGE));
    }

    function test_createTransfer_claim_fullFlow() public {
        uint256 amount = 100e6;
        uint64 expiry = uint64(block.timestamp + 1 days);
        uint256 expectedEscrow = amount - vault.FEE_6_DECIMALS();

        vm.startPrank(sender);
        usdc.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(usdc), amount, hashlock, expiry);
        vm.stopPrank();

        (
            address tSender,
            address tToken,
            uint256 tAmount,
            bytes32 tHashlock,
            uint64 tExpiry,
            bool tClaimed
        ) = vault.transfers(transferId);
        assertEq(tSender, sender);
        assertEq(tToken, address(usdc));
        assertEq(tAmount, expectedEscrow);
        assertEq(tHashlock, hashlock);
        assertEq(tExpiry, expiry);
        assertFalse(tClaimed);
        assertEq(usdc.balanceOf(address(vault)), amount);
        assertEq(usdc.balanceOf(sender), 1_000_000e6 - amount);

        bytes memory secret = abi.encode(SECRET_PREIMAGE);
        vm.prank(other);
        vault.claim(transferId, secret, receiver);

        (,,,,, bool tClaimedAfter) = vault.transfers(transferId);
        assertTrue(tClaimedAfter);
        assertEq(usdc.balanceOf(receiver), expectedEscrow);
        assertEq(usdc.balanceOf(address(vault)), vault.FEE_6_DECIMALS());
    }

    function test_createTransfer_withUSDT_retainsFeeAndEscrowsRest() public {
        uint256 amount = 100e6;
        uint64 expiry = uint64(block.timestamp + 1 days);
        uint256 expectedEscrow = amount - vault.FEE_6_DECIMALS();

        usdt.mint(sender, 1_000_000e6);

        vm.startPrank(sender);
        usdt.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(usdt), amount, hashlock, expiry);
        vm.stopPrank();

        (address tSender, address tToken, uint256 tAmount,,,) = vault.transfers(transferId);
        assertEq(tSender, sender);
        assertEq(tToken, address(usdt));
        assertEq(tAmount, expectedEscrow);

        assertEq(usdt.balanceOf(address(vault)), amount);

        bytes memory secret = abi.encode(SECRET_PREIMAGE);
        vm.prank(other);
        vault.claim(transferId, secret, receiver);

        assertEq(usdt.balanceOf(receiver), expectedEscrow);
        assertEq(usdt.balanceOf(address(vault)), vault.FEE_6_DECIMALS());
    }

    function test_createTransfer_revertZeroToken() public {
        vm.prank(sender);
        vm.expectRevert(ClaimVault.ZeroAddress.selector);
        vault.createTransfer(address(0), 100e6, hashlock, uint64(block.timestamp + 1 days));
    }

    function test_createTransfer_revertZeroAmount() public {
        vm.startPrank(sender);
        usdc.approve(address(vault), 100e6);
        vm.expectRevert(ClaimVault.ZeroAmount.selector);
        vault.createTransfer(address(usdc), 0, hashlock, uint64(block.timestamp + 1 days));
        vm.stopPrank();
    }

    function test_claim_revertWrongSecret() public {
        uint256 amount = 100e6;
        uint64 expiry = uint64(block.timestamp + 1 days);
        vm.startPrank(sender);
        usdc.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(usdc), amount, hashlock, expiry);
        vm.stopPrank();

        bytes memory wrongSecret = abi.encode(keccak256("wrong"));
        vm.prank(receiver);
        vm.expectRevert(ClaimVault.HashlockMismatch.selector);
        vault.claim(transferId, wrongSecret, receiver);
    }

    function test_claim_revertExpired() public {
        uint256 amount = 100e6;
        uint64 expiry = uint64(block.timestamp + 1 hours);
        vm.startPrank(sender);
        usdc.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(usdc), amount, hashlock, expiry);
        vm.stopPrank();

        vm.warp(expiry + 1);
        bytes memory secret = abi.encode(SECRET_PREIMAGE);
        vm.prank(receiver);
        vm.expectRevert(ClaimVault.Expired.selector);
        vault.claim(transferId, secret, receiver);
    }

    function test_claim_revertZeroReceiver() public {
        uint256 amount = 100e6;
        uint64 expiry = uint64(block.timestamp + 1 days);
        vm.startPrank(sender);
        usdc.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(usdc), amount, hashlock, expiry);
        vm.stopPrank();

        bytes memory secret = abi.encode(SECRET_PREIMAGE);
        vm.prank(receiver);
        vm.expectRevert(ClaimVault.ZeroAddress.selector);
        vault.claim(transferId, secret, address(0));
    }

    function test_claim_revertAlreadyClaimed() public {
        uint256 amount = 100e6;
        uint64 expiry = uint64(block.timestamp + 1 days);
        vm.startPrank(sender);
        usdc.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(usdc), amount, hashlock, expiry);
        vm.stopPrank();

        bytes memory secret = abi.encode(SECRET_PREIMAGE);
        vm.prank(receiver);
        vault.claim(transferId, secret, receiver);

        vm.prank(receiver);
        vm.expectRevert(ClaimVault.AlreadyClaimed.selector);
        vault.claim(transferId, secret, receiver);
    }

    function test_claim_revertTransferNotFound() public {
        bytes32 bogusId = bytes32(uint256(999));
        bytes memory secret = abi.encode(SECRET_PREIMAGE);
        vm.prank(receiver);
        vm.expectRevert(ClaimVault.TransferNotFound.selector);
        vault.claim(bogusId, secret, receiver);
    }

    function test_refund_afterExpiry() public {
        uint256 amount = 100e6;
        uint64 expiry = uint64(block.timestamp + 1 hours);
        uint256 expectedEscrow = amount - vault.FEE_6_DECIMALS();
        vm.startPrank(sender);
        usdc.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(usdc), amount, hashlock, expiry);
        vm.stopPrank();

        vm.warp(expiry + 1);
        uint256 senderBalBefore = usdc.balanceOf(sender);
        vm.prank(sender);
        vault.refund(transferId);

        (,,,,, bool tClaimed) = vault.transfers(transferId);
        assertTrue(tClaimed);
        assertEq(usdc.balanceOf(sender), senderBalBefore + expectedEscrow);
        assertEq(usdc.balanceOf(address(vault)), vault.FEE_6_DECIMALS());
    }

    function test_refund_revertNotExpired() public {
        uint256 amount = 100e6;
        uint64 expiry = uint64(block.timestamp + 1 days);
        vm.startPrank(sender);
        usdc.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(usdc), amount, hashlock, expiry);
        vm.stopPrank();

        vm.prank(sender);
        vm.expectRevert(ClaimVault.NotExpired.selector);
        vault.refund(transferId);
    }

    function test_refund_revertNotSender() public {
        uint256 amount = 100e6;
        uint64 expiry = uint64(block.timestamp + 1 hours);
        vm.startPrank(sender);
        usdc.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(usdc), amount, hashlock, expiry);
        vm.stopPrank();

        vm.warp(expiry + 1);
        vm.prank(other);
        vm.expectRevert(ClaimVault.NotSender.selector);
        vault.refund(transferId);
    }

    function test_refund_revertAlreadyClaimed() public {
        uint256 amount = 100e6;
        uint64 expiry = uint64(block.timestamp + 1 days);
        vm.startPrank(sender);
        usdc.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(usdc), amount, hashlock, expiry);
        vm.stopPrank();

        bytes memory secret = abi.encode(SECRET_PREIMAGE);
        vm.prank(receiver);
        vault.claim(transferId, secret, receiver);

        vm.prank(sender);
        vm.expectRevert(ClaimVault.AlreadyClaimed.selector);
        vault.refund(transferId);
    }

    function test_nextTransferId_increments() public {
        assertEq(vault.nextTransferId(), 0);
        vm.startPrank(sender);
        usdc.approve(address(vault), 150e6);
        vault.createTransfer(address(usdc), 100e6, hashlock, uint64(block.timestamp + 1 days));
        assertEq(vault.nextTransferId(), 1);
        vault.createTransfer(address(usdc), 50e6, hashlock, uint64(block.timestamp + 1 days));
        assertEq(vault.nextTransferId(), 2);
        vm.stopPrank();
    }

    function test_multipleTransfers_claimAndRefund() public {
        uint64 expirySoon = uint64(block.timestamp + 1 hours);
        uint64 expiryLater = uint64(block.timestamp + 2 days);
        vm.startPrank(sender);
        usdc.approve(address(vault), 200e6);
        bytes32 id1 = vault.createTransfer(address(usdc), 100e6, hashlock, expirySoon);
        bytes32 id2 = vault.createTransfer(address(usdc), 100e6, hashlock, expiryLater);
        vm.stopPrank();

        bytes memory secret = abi.encode(SECRET_PREIMAGE);
        vm.prank(receiver);
        vault.claim(id2, secret, receiver);
        assertEq(usdc.balanceOf(receiver), 100e6 - vault.FEE_6_DECIMALS());

        vm.warp(expirySoon + 1);
        vm.prank(sender);
        vault.refund(id1);
        assertEq(usdc.balanceOf(sender), 1_000_000e6 - 200e6 + (100e6 - vault.FEE_6_DECIMALS()));
    }
}

/// @notice USDC `createTransfer` must not invoke the Uniswap router (only ERC-20 transfer).
contract ClaimVaultUSDCTest is Test {
    ClaimVault vault;
    MockUSDC usdc;
    MockERC20 usdt;
    MockERC20 weth;
    RevertingSwapRouter router;

    address sender = address(0x10);
    bytes32 hashlock = keccak256(abi.encode(keccak256("secret")));

    function setUp() public {
        usdc = new MockUSDC();
        usdt = new MockERC20("USDT", "USDT", 6);
        weth = new MockERC20("WETH", "WETH", 18);
        router = new RevertingSwapRouter();
        vault = new ClaimVault(
            IERC20(address(usdc)), IERC20(address(usdt)), IERC20(address(weth)), ISwapRouterV3(address(router))
        );
        usdc.mint(sender, 1_000_000e6);
    }

    function test_USDC_createTransfer_doesNotCallSwapRouter() public {
        vm.startPrank(sender);
        usdc.approve(address(vault), 100e6);
        vault.createTransfer(address(usdc), 100e6, hashlock, uint64(block.timestamp + 1 days));
        vm.stopPrank();
    }
}

/// @notice Non-stable token path: `exactInput` on mock router, escrow USDC after fee.
contract ClaimVaultSwapRouterTest is Test {
    ClaimVault vault;
    MockUSDC usdc;
    MockERC20 usdt;
    MockERC20 weth;
    MockERC20 link;
    MockSwapRouterV3 router;

    address sender = address(0x20);
    address receiver = address(0x21);
    address other = address(0x22);
    bytes32 constant SWAP_SECRET_PREIMAGE = keccak256("swap-secret-preimage");
    bytes32 hashlock;

    function setUp() public {
        usdc = new MockUSDC();
        usdt = new MockERC20("USDT", "USDT", 6);
        weth = new MockERC20("WETH", "WETH", 18);
        link = new MockERC20("LINK", "LINK", 18);
        router = new MockSwapRouterV3(usdc);
        vault = new ClaimVault(
            IERC20(address(usdc)), IERC20(address(usdt)), IERC20(address(weth)), ISwapRouterV3(address(router))
        );
        vault.setDefaultFees(3000, 3000);
        link.mint(sender, 1_000e18);
        hashlock = keccak256(abi.encode(SWAP_SECRET_PREIMAGE));
    }

    function test_swapPath_createTransfer_claim_escrowsUSDC() public {
        uint256 amountIn = 1e18;
        uint64 expiry = uint64(block.timestamp + 1 days);
        uint256 fee = vault.FEE_6_DECIMALS();
        uint256 expectedEscrow = 10 * 1e6 - fee;

        vm.startPrank(sender);
        link.approve(address(vault), amountIn);
        bytes32 transferId = vault.createTransfer(address(link), amountIn, hashlock, expiry);
        vm.stopPrank();

        (address tSender, address tToken, uint256 tAmount,,,) = vault.transfers(transferId);
        assertEq(tSender, sender);
        assertEq(tToken, address(usdc));
        assertEq(tAmount, expectedEscrow);

        assertEq(usdc.balanceOf(address(vault)), 10 * 1e6);

        vm.prank(other);
        vault.claim(transferId, abi.encode(SWAP_SECRET_PREIMAGE), receiver);

        assertEq(usdc.balanceOf(receiver), expectedEscrow);
        assertEq(usdc.balanceOf(address(vault)), fee);
    }

    function test_swapPath_revertFeesNotSet() public {
        ClaimVault freshVault = new ClaimVault(
            IERC20(address(usdc)), IERC20(address(usdt)), IERC20(address(weth)), ISwapRouterV3(address(router))
        );
        // owner is this test contract; fees remain 0
        vm.startPrank(sender);
        link.approve(address(freshVault), 1e18);
        vm.expectRevert(ClaimVault.FeesNotSet.selector);
        freshVault.createTransfer(address(link), 1e18, hashlock, uint64(block.timestamp + 1 days));
        vm.stopPrank();
    }
}
