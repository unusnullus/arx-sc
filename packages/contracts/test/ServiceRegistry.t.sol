// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { StakingAccess } from "../src/services/StakingAccess.sol";
import { ServiceRegistry } from "../src/services/ServiceRegistry.sol";

contract MockARX2 is Test {
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

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract ServiceRegistryTest is Test {
    MockARX2 arx;
    StakingAccess staking;
    ServiceRegistry registry;
    address owner = address(0xABCD);
    address user = address(0xBEEF);

    function setUp() public {
        arx = new MockARX2();
        {
            StakingAccess impl = new StakingAccess();
            uint256[] memory tiers = new uint256[](1);
            tiers[0] = 1_000_000; // 1 ARX required
            bytes memory init = abi.encodeWithSelector(
                StakingAccess.initialize.selector, IERC20(address(arx)), owner, tiers
            );
            ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
            staking = StakingAccess(address(proxy));
        }
        {
            ServiceRegistry implR = new ServiceRegistry();
            bytes memory initR =
                abi.encodeWithSelector(ServiceRegistry.initialize.selector, staking, owner);
            ERC1967Proxy proxyR = new ERC1967Proxy(address(implR), initR);
            registry = ServiceRegistry(address(proxyR));
        }

        // fund user and approve staking
        arx.mint(user, 2_000_000);
        vm.prank(user);
        arx.approve(address(staking), type(uint256).max);
    }

    function test_register_requires_tier_and_eoa() public {
        // no stake yet -> should revert on tier
        vm.prank(user, user);
        vm.expectRevert(bytes("Tier too low"));
        registry.register(ServiceRegistry.ServiceType.VPN, "ipfs://vpn-a");

        // stake and register
        vm.prank(user, user);
        staking.stake(1_000_000);
        vm.prank(user, user);
        bytes32 id = registry.register(ServiceRegistry.ServiceType.VPN, "ipfs://vpn-a");
        // enabled services should contain VPN
        ServiceRegistry.ServiceType[] memory s = registry.enabledServices(user);
        bool found;
        for (uint256 i = 0; i < s.length; i++) {
            if (s[i] == ServiceRegistry.ServiceType.VPN) found = true;
        }
        assertTrue(found);
    }

    function test_update_active_affects_enabled() public {
        vm.prank(user, user);
        staking.stake(1_000_000);
        vm.prank(user, user);
        bytes32 id = registry.register(ServiceRegistry.ServiceType.C_CARD, "ipfs://card-a");
        // now disable
        vm.prank(user, user);
        registry.update(id, "ipfs://card-a", false);
        ServiceRegistry.ServiceType[] memory s = registry.enabledServices(user);
        bool found;
        for (uint256 i = 0; i < s.length; i++) {
            if (s[i] == ServiceRegistry.ServiceType.C_CARD) found = true;
        }
        assertTrue(!found);
    }
}
