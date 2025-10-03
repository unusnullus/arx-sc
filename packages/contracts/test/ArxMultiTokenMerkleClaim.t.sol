// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { ArxMultiTokenMerkleClaim } from "../src/claimable/ArxMultiTokenMerkleClaim.sol";

contract MockERC20 is Test {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract ArxMultiTokenMerkleClaimTest is Test {
    MockERC20 token;
    ArxMultiTokenMerkleClaim claim;
    address owner = address(0xABCD);
    address user = address(0xBEEF);

    function setUp() public {
        token = new MockERC20();
        ArxMultiTokenMerkleClaim impl = new ArxMultiTokenMerkleClaim();
        bytes memory init =
            abi.encodeWithSelector(ArxMultiTokenMerkleClaim.initialize.selector, owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
        claim = ArxMultiTokenMerkleClaim(address(proxy));

        // fund contract with tokens for distribution
        token.mint(address(claim), 1_000_000);
    }

    function _buildRoot(address account, uint256 amount)
        internal
        pure
        returns (bytes32 root, bytes32[] memory proof)
    {
        // single-leaf tree: root = leaf; empty proof
        root = keccak256(abi.encodePacked(account, amount));
        proof = new bytes32[](0);
    }

    function test_claim_single_root() public {
        (bytes32 root, bytes32[] memory proof) = _buildRoot(user, 100_000);
        vm.prank(owner);
        claim.addMerkleRoot(address(token), root);

        uint256 before = token.balanceOf(user);
        vm.prank(user);
        uint256 claimed = claim.claim(address(token), 100_000, proof);
        uint256 afterBal = token.balanceOf(user);
        assertEq(claimed, 100_000);
        assertEq(afterBal - before, 100_000);

        // second claim with same total should revert (already claimed)
        vm.expectRevert(bytes("Already claimed"));
        vm.prank(user);
        claim.claim(address(token), 100_000, proof);
    }

    function test_claim_across_two_roots() public {
        (bytes32 root1, bytes32[] memory proof1) = _buildRoot(user, 50_000);
        (bytes32 root2, bytes32[] memory proof2) = _buildRoot(user, 120_000);
        vm.startPrank(owner);
        claim.addMerkleRoot(address(token), root1);
        claim.addMerkleRoot(address(token), root2);
        vm.stopPrank();

        vm.prank(user);
        uint256 c1 = claim.claim(address(token), 50_000, proof1);
        assertEq(c1, 50_000);

        vm.prank(user);
        uint256 c2 = claim.claim(address(token), 120_000, proof2);
        assertEq(c2, 120_000);
    }
}
