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

    function test_AddMerkleRootWithDetails() public {
        (bytes32 root, bytes32[] memory proof) = _buildRoot(user, 100_000);
        string memory details = "ipfs://QmTest123";
        
        vm.prank(owner);
        claim.addMerkleRootWithDetails(address(token), root, details);
        
        assertEq(claim.getMerkleRootDetails(root), details);
        bytes32[] memory roots = claim.getMerkleRoots(address(token));
        assertEq(roots.length, 1);
        assertEq(roots[0], root);
    }

    function test_SetMerkleRootDetails() public {
        (bytes32 root, bytes32[] memory proof) = _buildRoot(user, 100_000);
        
        vm.startPrank(owner);
        claim.addMerkleRoot(address(token), root);
        claim.setMerkleRootDetails(root, "Updated details");
        vm.stopPrank();
        
        assertEq(claim.getMerkleRootDetails(root), "Updated details");
    }

    function test_GetMerkleRootsWithDetails() public {
        (bytes32 root1, bytes32[] memory proof1) = _buildRoot(user, 50_000);
        (bytes32 root2, bytes32[] memory proof2) = _buildRoot(user, 100_000);
        
        vm.startPrank(owner);
        claim.addMerkleRootWithDetails(address(token), root1, "Details 1");
        claim.addMerkleRootWithDetails(address(token), root2, "Details 2");
        vm.stopPrank();
        
        (bytes32[] memory roots, ArxMultiTokenMerkleClaim.MerkleRootInfo[] memory infos) = 
            claim.getMerkleRootsWithDetails(address(token));
        
        assertEq(roots.length, 2);
        assertEq(infos.length, 2);
        assertEq(infos[0].root, root1);
        assertEq(infos[0].details, "Details 1");
        assertEq(infos[1].root, root2);
        assertEq(infos[1].details, "Details 2");
    }

    function test_GetTotalClaimedForToken() public {
        (bytes32 root1, bytes32[] memory proof1) = _buildRoot(user, 50_000);
        (bytes32 root2, bytes32[] memory proof2) = _buildRoot(user, 100_000);
        
        vm.startPrank(owner);
        claim.addMerkleRoot(address(token), root1);
        claim.addMerkleRoot(address(token), root2);
        vm.stopPrank();
        
        vm.prank(user);
        claim.claim(address(token), 50_000, proof1);
        
        vm.prank(user);
        claim.claim(address(token), 100_000, proof2);
        
        uint256 totalClaimed = claim.getTotalClaimedForToken(user, address(token));
        assertEq(totalClaimed, 150_000);
    }

    function test_GetClaimedForTokenAndRoot() public {
        (bytes32 root, bytes32[] memory proof) = _buildRoot(user, 100_000);
        
        vm.prank(owner);
        claim.addMerkleRoot(address(token), root);
        
        vm.prank(user);
        claim.claim(address(token), 100_000, proof);
        
        uint256 claimed = claim.getClaimedForTokenAndRoot(user, root);
        assertEq(claimed, 100_000);
    }

    function test_GetTotalClaimedForAllTokens() public {
        MockERC20 token2 = new MockERC20();
        token2.mint(address(claim), 1_000_000);
        
        (bytes32 root1, bytes32[] memory proof1) = _buildRoot(user, 50_000);
        (bytes32 root2, bytes32[] memory proof2) = _buildRoot(user, 75_000);
        
        vm.startPrank(owner);
        claim.addMerkleRoot(address(token), root1);
        claim.addMerkleRoot(address(token2), root2);
        vm.stopPrank();
        
        vm.prank(user);
        claim.claim(address(token), 50_000, proof1);
        
        vm.prank(user);
        claim.claim(address(token2), 75_000, proof2);
        
        uint256 totalClaimed = claim.getTotalClaimedForAllTokens(user);
        assertEq(totalClaimed, 125_000);
    }

    function test_IsClaimed() public {
        (bytes32 root, bytes32[] memory proof) = _buildRoot(user, 100_000);
        
        vm.prank(owner);
        claim.addMerkleRoot(address(token), root);
        
        assertFalse(claim.isClaimed(address(token), 0, user));
        
        vm.prank(user);
        claim.claim(address(token), 100_000, proof);
        
        assertTrue(claim.isClaimed(address(token), 0, user));
    }

    function test_IsClaimed_InvalidIndex() public {
        assertFalse(claim.isClaimed(address(token), 999, user));
    }

    function test_Withdraw() public {
        address recipient = address(0x999);
        uint256 contractBalance = token.balanceOf(address(claim));
        
        vm.prank(owner);
        claim.withdraw(address(token), recipient);
        
        assertEq(token.balanceOf(recipient), contractBalance);
        assertEq(token.balanceOf(address(claim)), 0);
    }

    function test_Withdraw_MultipleTokens() public {
        MockERC20 token2 = new MockERC20();
        token2.mint(address(claim), 500_000);
        address recipient = address(0x999);
        
        vm.startPrank(owner);
        claim.withdraw(address(token), recipient);
        claim.withdraw(address(token2), recipient);
        vm.stopPrank();
        
        assertEq(token.balanceOf(recipient), 1_000_000);
        assertEq(token2.balanceOf(recipient), 500_000);
    }

    function test_GetMerkleRoots() public {
        (bytes32 root1, bytes32[] memory proof1) = _buildRoot(user, 50_000);
        (bytes32 root2, bytes32[] memory proof2) = _buildRoot(user, 100_000);
        
        vm.startPrank(owner);
        claim.addMerkleRoot(address(token), root1);
        claim.addMerkleRoot(address(token), root2);
        vm.stopPrank();
        
        bytes32[] memory roots = claim.getMerkleRoots(address(token));
        assertEq(roots.length, 2);
        assertEq(roots[0], root1);
        assertEq(roots[1], root2);
    }

    function test_Claim_Partial() public {
        (bytes32 root, bytes32[] memory proof) = _buildRoot(user, 100_000);
        
        vm.prank(owner);
        claim.addMerkleRoot(address(token), root);
        
        // First claim
        vm.prank(user);
        uint256 claimed1 = claim.claim(address(token), 100_000, proof);
        assertEq(claimed1, 100_000);
        
        // Try to claim again - should revert
        vm.expectRevert(bytes("Already claimed"));
        vm.prank(user);
        claim.claim(address(token), 100_000, proof);
    }

    function test_RevertWhen_AddMerkleRoot_ZeroAddress() public {
        (bytes32 root, bytes32[] memory proof) = _buildRoot(user, 100_000);
        
        vm.prank(owner);
        vm.expectRevert(ArxMultiTokenMerkleClaim.ZeroAddress.selector);
        claim.addMerkleRoot(address(0), root);
    }

    function test_RevertWhen_AddMerkleRootWithDetails_ZeroAddress() public {
        (bytes32 root, bytes32[] memory proof) = _buildRoot(user, 100_000);
        
        vm.prank(owner);
        vm.expectRevert(ArxMultiTokenMerkleClaim.ZeroAddress.selector);
        claim.addMerkleRootWithDetails(address(0), root, "details");
    }

    function test_RevertWhen_Withdraw_ZeroRecipient() public {
        vm.prank(owner);
        vm.expectRevert(ArxMultiTokenMerkleClaim.ZeroAddress.selector);
        claim.withdraw(address(token), address(0));
    }

    function test_RevertWhen_Claim_InvalidProof() public {
        (bytes32 root, bytes32[] memory proof) = _buildRoot(user, 100_000);
        
        vm.prank(owner);
        claim.addMerkleRoot(address(token), root);
        
        // Invalid proof
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = bytes32(uint256(123));
        
        vm.expectRevert(bytes("Invalid proof"));
        vm.prank(user);
        claim.claim(address(token), 100_000, invalidProof);
    }

    function test_GetMerkleRootDetails_Empty() public {
        bytes32 root = bytes32(uint256(123));
        assertEq(claim.getMerkleRootDetails(root), "");
    }
}
