// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { StakingAccess } from "../src/services/StakingAccess.sol";

contract MockARX is Test {
    string public name = "ARX NET Slice";
    string public symbol = "ARX";
    uint8 public constant decimals = 6;

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

contract StakingAccessTest is Test {
    MockARX arx;
    StakingAccess staking;
    address owner = address(0xABCD);
    address user = address(0xBEEF);

    function setUp() public {
        arx = new MockARX();
        StakingAccess impl = new StakingAccess();
        uint256[] memory tiers = new uint256[](3);
        tiers[0] = 1_000_000; // 1 ARX
        tiers[1] = 10_000_000; // 10 ARX
        tiers[2] = 100_000_000; // 100 ARX
        bytes memory data = abi.encodeWithSelector(
            StakingAccess.initialize.selector, IERC20(address(arx)), owner, tiers
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), data);
        staking = StakingAccess(address(proxy));

        // fund user
        arx.mint(user, 200_000_000);
        vm.prank(user);
        arx.approve(address(staking), type(uint256).max);
    }

    function test_stake_and_tiers() public {
        // below first tier
        assertEq(staking.tierOf(user), 0);
        vm.prank(user);
        staking.stake(1_000_000);
        assertEq(staking.tierOf(user), 1);

        vm.prank(user);
        staking.stake(9_000_000);
        assertEq(staking.tierOf(user), 2);

        vm.prank(user);
        staking.stake(90_000_000);
        assertEq(staking.tierOf(user), 3);
    }

    function test_unstake_cooldown_and_claim() public {
        vm.prank(user);
        staking.stake(5_000_000);
        assertEq(staking.tierOf(user), 1);

        // request unstake 4 ARX; reduces staked to 1 ARX which remains Tier 1
        vm.prank(user);
        staking.requestUnstake(4_000_000);
        assertEq(staking.tierOf(user), 1);

        // cannot claim before 30 days
        vm.prank(user);
        vm.expectRevert();
        staking.claimUnstaked();

        // warp 30 days and claim
        vm.warp(block.timestamp + 30 days);
        uint256 before = arx.balanceOf(user);
        vm.prank(user);
        staking.claimUnstaked();
        uint256 afterBal = arx.balanceOf(user);
        assertEq(afterBal - before, 4_000_000);
    }
}
