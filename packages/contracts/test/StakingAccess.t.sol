// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StakingAccess} from "../src/services/StakingAccess.sol";

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

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max)
            allowance[from][msg.sender] = allowed - amount;
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
            StakingAccess.initialize.selector,
            IERC20(address(arx)),
            owner,
            tiers
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

    function test_RevertWhen_InitializeWithZeroARX() public {
        StakingAccess impl = new StakingAccess();
        uint256[] memory _tiers = new uint256[](3);
        _tiers[0] = 1e6;
        _tiers[1] = 10e6;
        _tiers[2] = 100e6;

        bytes memory data = abi.encodeWithSelector(
            StakingAccess.initialize.selector,
            IERC20(address(0)),
            owner,
            _tiers
        );
        vm.expectRevert(StakingAccess.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), data);
    }

    function test_RevertWhen_InitializeWithZeroOwner() public {
        StakingAccess impl = new StakingAccess();
        uint256[] memory _tiers = new uint256[](3);
        _tiers[0] = 1e6;
        _tiers[1] = 10e6;
        _tiers[2] = 100e6;

        bytes memory data = abi.encodeWithSelector(
            StakingAccess.initialize.selector,
            arx,
            address(0),
            _tiers
        );
        vm.expectRevert(StakingAccess.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), data);
    }

    function test_RevertWhen_InitializeWithEmptyTiers() public {
        StakingAccess impl = new StakingAccess();
        uint256[] memory _tiers = new uint256[](0);

        bytes memory data = abi.encodeWithSelector(
            StakingAccess.initialize.selector,
            arx,
            owner,
            _tiers
        );
        vm.expectRevert(StakingAccess.InvalidTiers.selector);
        new ERC1967Proxy(address(impl), data);
    }

    function test_RevertWhen_InitializeWithZeroTier() public {
        StakingAccess impl = new StakingAccess();
        uint256[] memory _tiers = new uint256[](3);
        _tiers[0] = 1e6;
        _tiers[1] = 0; // Invalid zero tier
        _tiers[2] = 100e6;

        bytes memory data = abi.encodeWithSelector(
            StakingAccess.initialize.selector,
            arx,
            owner,
            _tiers
        );
        vm.expectRevert(StakingAccess.InvalidTiers.selector);
        new ERC1967Proxy(address(impl), data);
    }

    function test_RevertWhen_InitializeWithNonAscendingTiers() public {
        StakingAccess impl = new StakingAccess();
        uint256[] memory _tiers = new uint256[](3);
        _tiers[0] = 1e6;
        _tiers[1] = 100e6;
        _tiers[2] = 10e6; // Not ascending

        bytes memory data = abi.encodeWithSelector(
            StakingAccess.initialize.selector,
            arx,
            owner,
            _tiers
        );
        vm.expectRevert(StakingAccess.InvalidTiers.selector);
        new ERC1967Proxy(address(impl), data);
    }

    function test_RevertWhen_StakeZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(StakingAccess.ZeroAmount.selector);
        staking.stake(0);
    }

    function test_RevertWhen_UnstakeZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(StakingAccess.ZeroAmount.selector);
        staking.requestUnstake(0);
    }

    function test_RevertWhen_UnstakeMoreThanStaked() public {
        vm.startPrank(user);
        staking.stake(10e6);

        vm.expectRevert(StakingAccess.InsufficientStake.selector);
        staking.requestUnstake(11e6);
        vm.stopPrank();
    }

    function test_RevertWhen_ClaimWithNoPending() public {
        vm.prank(user);
        vm.expectRevert(StakingAccess.NothingToClaim.selector);
        staking.claimUnstaked();
    }

    function test_RevertWhen_ClaimBeforeCooldown() public {
        vm.startPrank(user);
        staking.stake(10e6);
        staking.requestUnstake(5e6);

        // Try to claim immediately
        vm.expectRevert();
        staking.claimUnstaked();
        vm.stopPrank();
    }

    function test_MultipleUnstakeRequestsExtendCooldown() public {
        vm.startPrank(user);
        staking.stake(20e6);

        // First unstake request
        staking.requestUnstake(5e6);
        (, uint256 firstAvailableAt) = staking.pendingUnstake(user);

        // Wait 10 days
        vm.warp(block.timestamp + 10 days);

        // Second unstake request - should extend cooldown
        staking.requestUnstake(5e6);
        (uint256 totalPending, uint256 secondAvailableAt) = staking
            .pendingUnstake(user);

        assertEq(totalPending, 10e6);
        assertGt(secondAvailableAt, firstAvailableAt);
        assertEq(secondAvailableAt, block.timestamp + 30 days);
        vm.stopPrank();
    }

    function test_TierUpdateByOwner() public {
        uint256[] memory newTiers = new uint256[](2);
        newTiers[0] = 5e6;
        newTiers[1] = 50e6;

        vm.prank(owner);
        staking.setTiers(newTiers);

        assertEq(staking.tiers(0), 5e6);
        assertEq(staking.tiers(1), 50e6);
    }

    function test_RevertWhen_NonOwnerSetsTiers() public {
        uint256[] memory newTiers = new uint256[](2);
        newTiers[0] = 5e6;
        newTiers[1] = 50e6;

        vm.prank(user);
        vm.expectRevert();
        staking.setTiers(newTiers);
    }

    function test_PendingUnstakeDoesNotCountTowardTier() public {
        vm.startPrank(user);
        staking.stake(100e6);
        assertEq(staking.tierOf(user), 3); // Tier 3

        // Request unstake - tier should drop
        staking.requestUnstake(90e6);
        assertEq(staking.tierOf(user), 2); // Now tier 2 with only 10e6 staked
        vm.stopPrank();
    }
}
