// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ClaimVault } from "../src/claimable/ClaimVault.sol";
import { MockUSDC } from "../src/mocks/MockUSDC.sol";

contract ClaimVaultTest is Test {
    ClaimVault vault;
    MockUSDC token;

    address sender = address(0x1);
    address receiver = address(0x2);
    address other = address(0x3);

    bytes32 constant SECRET_PREIMAGE = keccak256("my-secret");
    bytes32 hashlock;

    function setUp() public {
        vault = new ClaimVault();
        token = new MockUSDC();
        token.mint(sender, 1_000_000e6);
        hashlock = keccak256(abi.encode(SECRET_PREIMAGE));
    }

    function test_createTransfer_claim_fullFlow() public {
        uint256 amount = 100e6;
        uint64 expiry = uint64(block.timestamp + 1 days);

        vm.startPrank(sender);
        token.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(token), amount, hashlock, expiry);
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
        assertEq(tToken, address(token));
        assertEq(tAmount, amount);
        assertEq(tHashlock, hashlock);
        assertEq(tExpiry, expiry);
        assertFalse(tClaimed);
        assertEq(token.balanceOf(address(vault)), amount);
        assertEq(token.balanceOf(sender), 1_000_000e6 - amount);

        bytes memory secret = abi.encode(SECRET_PREIMAGE);
        vm.prank(other);
        vault.claim(transferId, secret, receiver);

        (,,,,, bool tClaimedAfter) = vault.transfers(transferId);
        assertTrue(tClaimedAfter);
        assertEq(token.balanceOf(receiver), amount);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function test_createTransfer_revertZeroToken() public {
        vm.prank(sender);
        vm.expectRevert(ClaimVault.ZeroAddress.selector);
        vault.createTransfer(address(0), 100e6, hashlock, uint64(block.timestamp + 1 days));
    }

    function test_createTransfer_revertZeroAmount() public {
        vm.startPrank(sender);
        token.approve(address(vault), 100e6);
        vm.expectRevert(ClaimVault.ZeroAmount.selector);
        vault.createTransfer(address(token), 0, hashlock, uint64(block.timestamp + 1 days));
        vm.stopPrank();
    }

    function test_claim_revertWrongSecret() public {
        uint256 amount = 100e6;
        uint64 expiry = uint64(block.timestamp + 1 days);
        vm.startPrank(sender);
        token.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(token), amount, hashlock, expiry);
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
        token.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(token), amount, hashlock, expiry);
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
        token.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(token), amount, hashlock, expiry);
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
        token.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(token), amount, hashlock, expiry);
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
        vm.startPrank(sender);
        token.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(token), amount, hashlock, expiry);
        vm.stopPrank();

        vm.warp(expiry + 1);
        uint256 senderBalBefore = token.balanceOf(sender);
        vm.prank(sender);
        vault.refund(transferId);

        (,,,,, bool tClaimed) = vault.transfers(transferId);
        assertTrue(tClaimed);
        assertEq(token.balanceOf(sender), senderBalBefore + amount);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function test_refund_revertNotExpired() public {
        uint256 amount = 100e6;
        uint64 expiry = uint64(block.timestamp + 1 days);
        vm.startPrank(sender);
        token.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(token), amount, hashlock, expiry);
        vm.stopPrank();

        vm.prank(sender);
        vm.expectRevert(ClaimVault.NotExpired.selector);
        vault.refund(transferId);
    }

    function test_refund_revertNotSender() public {
        uint256 amount = 100e6;
        uint64 expiry = uint64(block.timestamp + 1 hours);
        vm.startPrank(sender);
        token.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(token), amount, hashlock, expiry);
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
        token.approve(address(vault), amount);
        bytes32 transferId = vault.createTransfer(address(token), amount, hashlock, expiry);
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
        token.approve(address(vault), 100e6);
        vault.createTransfer(address(token), 100e6, hashlock, uint64(block.timestamp + 1 days));
        assertEq(vault.nextTransferId(), 1);
        vault.createTransfer(address(token), 50e6, hashlock, uint64(block.timestamp + 1 days));
        assertEq(vault.nextTransferId(), 2);
        vm.stopPrank();
    }

    function test_multipleTransfers_claimAndRefund() public {
        uint64 expirySoon = uint64(block.timestamp + 1 hours);
        uint64 expiryLater = uint64(block.timestamp + 2 days);
        vm.startPrank(sender);
        token.approve(address(vault), 200e6);
        bytes32 id1 = vault.createTransfer(address(token), 100e6, hashlock, expirySoon);
        bytes32 id2 = vault.createTransfer(address(token), 100e6, hashlock, expiryLater);
        vm.stopPrank();

        bytes memory secret = abi.encode(SECRET_PREIMAGE);
        vm.prank(receiver);
        vault.claim(id2, secret, receiver);
        assertEq(token.balanceOf(receiver), 100e6);

        vm.warp(expirySoon + 1);
        vm.prank(sender);
        vault.refund(id1);
        assertEq(token.balanceOf(sender), 1_000_000e6 - 100e6);
    }
}
