// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StakingAccess} from "../src/services/StakingAccess.sol";
import {ServiceRegistry} from "../src/services/ServiceRegistry.sol";

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
                StakingAccess.initialize.selector,
                IERC20(address(arx)),
                owner,
                tiers
            );
            ERC1967Proxy proxy = new ERC1967Proxy(address(impl), init);
            staking = StakingAccess(address(proxy));
        }
        {
            ServiceRegistry implR = new ServiceRegistry();
            bytes memory initR = abi.encodeWithSelector(
                ServiceRegistry.initialize.selector,
                staking,
                owner
            );
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
        bytes32 id = registry.register(
            ServiceRegistry.ServiceType.VPN,
            "ipfs://vpn-a"
        );
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
        bytes32 id = registry.register(
            ServiceRegistry.ServiceType.C_CARD,
            "ipfs://card-a"
        );
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

    function test_Register_AllServiceTypes() public {
        vm.prank(user, user);
        staking.stake(1_000_000);

        vm.startPrank(user, user);
        registry.register(ServiceRegistry.ServiceType.Relay, "ipfs://relay");
        registry.register(ServiceRegistry.ServiceType.VPN, "ipfs://vpn");
        registry.register(
            ServiceRegistry.ServiceType.Merchant,
            "ipfs://merchant"
        );
        registry.register(ServiceRegistry.ServiceType.C_VPN, "ipfs://c-vpn");
        registry.register(
            ServiceRegistry.ServiceType.C_CLOUD,
            "ipfs://c-cloud"
        );
        registry.register(ServiceRegistry.ServiceType.C_CARD, "ipfs://c-card");
        registry.register(ServiceRegistry.ServiceType.C_ESIM, "ipfs://c-esim");
        registry.register(
            ServiceRegistry.ServiceType.C_SECURE_MODE,
            "ipfs://c-secure"
        );
        registry.register(
            ServiceRegistry.ServiceType.C_ULTRA,
            "ipfs://c-ultra"
        );
        vm.stopPrank();

        ServiceRegistry.ServiceType[] memory enabled = registry.enabledServices(
            user
        );
        assertEq(enabled.length, 9);
    }

    function test_Update_Reenable() public {
        vm.prank(user, user);
        staking.stake(1_000_000);
        vm.prank(user, user);
        bytes32 id = registry.register(
            ServiceRegistry.ServiceType.VPN,
            "ipfs://vpn-a"
        );

        // Disable
        vm.prank(user, user);
        registry.update(id, "ipfs://vpn-a", false);

        ServiceRegistry.ServiceType[] memory s = registry.enabledServices(user);
        assertEq(s.length, 0);

        // Re-enable
        vm.prank(user, user);
        registry.update(id, "ipfs://vpn-a-updated", true);

        s = registry.enabledServices(user);
        assertEq(s.length, 1);
        assertEq(uint256(s[0]), uint256(ServiceRegistry.ServiceType.VPN));
    }

    function test_Update_Metadata() public {
        vm.prank(user, user);
        staking.stake(1_000_000);
        vm.prank(user, user);
        bytes32 id = registry.register(
            ServiceRegistry.ServiceType.VPN,
            "ipfs://vpn-a"
        );

        vm.prank(user, user);
        registry.update(id, "ipfs://vpn-b", true);

        (
            address serviceOwner,
            ServiceRegistry.ServiceType serviceType,
            string memory metadata,
            bool active
        ) = registry.services(id);
        assertEq(serviceOwner, user);
        assertEq(
            uint256(serviceType),
            uint256(ServiceRegistry.ServiceType.VPN)
        );
        assertEq(metadata, "ipfs://vpn-b");
        assertTrue(active);
    }

    function test_Update_MultipleServices_SameType() public {
        vm.prank(user, user);
        staking.stake(1_000_000);

        vm.startPrank(user, user);
        bytes32 id1 = registry.register(
            ServiceRegistry.ServiceType.VPN,
            "ipfs://vpn-1"
        );
        bytes32 id2 = registry.register(
            ServiceRegistry.ServiceType.VPN,
            "ipfs://vpn-2"
        );
        vm.stopPrank();

        ServiceRegistry.ServiceType[] memory s = registry.enabledServices(user);
        assertEq(s.length, 1); // Only one type, but two services

        // Disable one
        vm.prank(user, user);
        registry.update(id1, "ipfs://vpn-1", false);

        // Still enabled because id2 is active
        s = registry.enabledServices(user);
        assertEq(s.length, 1);

        // Disable both
        vm.prank(user, user);
        registry.update(id2, "ipfs://vpn-2", false);

        s = registry.enabledServices(user);
        assertEq(s.length, 0);
    }

    function test_RevertWhen_Register_NotEOA() public {
        vm.prank(user, user);
        staking.stake(1_000_000);

        // Create a contract caller
        ContractCaller caller = new ContractCaller(registry);
        vm.expectRevert(ServiceRegistry.NotEOA.selector);
        caller.register(ServiceRegistry.ServiceType.VPN, "ipfs://vpn");
    }

    function test_RevertWhen_Update_Unauthorized() public {
        address otherUser = address(0x999);
        vm.prank(user, user);
        staking.stake(1_000_000);
        vm.prank(user, user);
        bytes32 id = registry.register(
            ServiceRegistry.ServiceType.VPN,
            "ipfs://vpn-a"
        );

        vm.prank(otherUser, otherUser);
        vm.expectRevert(ServiceRegistry.Unauthorized.selector);
        registry.update(id, "ipfs://vpn-b", true);
    }

    function test_RevertWhen_Initialize_ZeroStaking() public {
        ServiceRegistry impl = new ServiceRegistry();
        bytes memory init = abi.encodeWithSelector(
            ServiceRegistry.initialize.selector,
            staking,
            address(0)
        );
        vm.expectRevert(ServiceRegistry.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), init);
    }

    function test_RevertWhen_Initialize_ZeroOwner() public {
        ServiceRegistry impl = new ServiceRegistry();
        bytes memory init = abi.encodeWithSelector(
            ServiceRegistry.initialize.selector,
            staking,
            address(0)
        );
        vm.expectRevert(ServiceRegistry.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), init);
    }

    function test_EnabledServices_Empty() public {
        ServiceRegistry.ServiceType[] memory s = registry.enabledServices(user);
        assertEq(s.length, 0);
    }

    function test_EnabledServices_MultipleTypes() public {
        vm.prank(user, user);
        staking.stake(1_000_000);

        vm.startPrank(user, user);
        registry.register(ServiceRegistry.ServiceType.Relay, "ipfs://relay");
        registry.register(ServiceRegistry.ServiceType.VPN, "ipfs://vpn");
        registry.register(
            ServiceRegistry.ServiceType.Merchant,
            "ipfs://merchant"
        );
        vm.stopPrank();

        ServiceRegistry.ServiceType[] memory s = registry.enabledServices(user);
        assertEq(s.length, 3);
    }
}

contract ContractCaller {
    ServiceRegistry registry;

    constructor(ServiceRegistry _registry) {
        registry = _registry;
    }

    function register(
        ServiceRegistry.ServiceType serviceType,
        string calldata metadata
    ) external {
        registry.register(serviceType, metadata);
    }
}
