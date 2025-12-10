// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ArxTimelock} from "../src/governance/ArxTimelock.sol";

contract MockTarget {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }
}

contract ArxTimelockTest is Test {
    ArxTimelock timelock;
    MockTarget target;
    address admin = address(0xA11CE);
    address proposer = address(0xBEEF);
    address executor = address(0xCAFE);
    uint256 minDelay = 1 days;

    function setUp() public {
        target = new MockTarget();

        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        address[] memory executors = new address[](1);
        executors[0] = executor;

        ArxTimelock impl = new ArxTimelock();
        bytes memory data = abi.encodeWithSelector(
            ArxTimelock.initialize.selector,
            minDelay,
            proposers,
            executors,
            admin
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), data);
        timelock = ArxTimelock(payable(address(proxy)));

        // Grant CANCELLER_ROLE to proposer so they can cancel
        // Admin has DEFAULT_ADMIN_ROLE from initialization
        vm.startPrank(admin);
        timelock.grantRole(timelock.CANCELLER_ROLE(), proposer);
        vm.stopPrank();
    }

    function test_Initialize() public {
        assertEq(timelock.getMinDelay(), minDelay);
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), proposer));
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), executor));
        assertTrue(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_Schedule() public {
        address[] memory targets = new address[](1);
        targets[0] = address(target);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory payloads = new bytes[](1);
        payloads[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        // hashOperationBatch is view, doesn't need prank
        bytes32 id = timelock.hashOperationBatch(
            targets,
            values,
            payloads,
            bytes32(0),
            salt
        );

        vm.prank(proposer);
        timelock.scheduleBatch(
            targets,
            values,
            payloads,
            bytes32(0),
            salt,
            minDelay
        );

        assertGt(uint256(id), 0);
        assertTrue(timelock.isOperationPending(id));
    }

    function test_Execute() public {
        address[] memory targets = new address[](1);
        targets[0] = address(target);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory payloads = new bytes[](1);
        payloads[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        // Schedule
        bytes32 id = timelock.hashOperationBatch(
            targets,
            values,
            payloads,
            bytes32(0),
            salt
        );
        vm.prank(proposer);
        timelock.scheduleBatch(
            targets,
            values,
            payloads,
            bytes32(0),
            salt,
            minDelay
        );

        // Wait for delay
        vm.warp(block.timestamp + minDelay);

        // Execute
        vm.prank(executor);
        timelock.executeBatch(targets, values, payloads, bytes32(0), salt);

        assertEq(target.value(), 42);
        assertTrue(timelock.isOperationDone(id));
    }

    function test_RevertWhen_ExecuteBeforeDelay() public {
        address[] memory targets = new address[](1);
        targets[0] = address(target);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory payloads = new bytes[](1);
        payloads[0] = abi.encodeWithSelector(MockTarget.setValue.selector, 42);
        bytes32 salt = keccak256("test");

        vm.prank(proposer);
        timelock.scheduleBatch(
            targets,
            values,
            payloads,
            bytes32(0),
            salt,
            minDelay
        );

        // Try to execute before delay
        vm.prank(executor);
        vm.expectRevert();
        timelock.executeBatch(targets, values, payloads, bytes32(0), salt);
    }

    function test_RevertWhen_NonProposerSchedules() public {
        address[] memory targets = new address[](1);
        targets[0] = address(target);
        uint256[] memory values = new uint256[](1);
        bytes[] memory payloads = new bytes[](1);
        bytes32 salt = keccak256("test");

        vm.prank(admin);
        vm.expectRevert();
        timelock.scheduleBatch(
            targets,
            values,
            payloads,
            bytes32(0),
            salt,
            minDelay
        );
    }

    function test_RevertWhen_NonExecutorExecutes() public {
        address[] memory targets = new address[](1);
        targets[0] = address(target);
        uint256[] memory values = new uint256[](1);
        bytes[] memory payloads = new bytes[](1);
        bytes32 salt = keccak256("test");

        vm.prank(proposer);
        timelock.scheduleBatch(
            targets,
            values,
            payloads,
            bytes32(0),
            salt,
            minDelay
        );

        vm.warp(block.timestamp + minDelay);

        vm.prank(admin);
        vm.expectRevert();
        timelock.executeBatch(targets, values, payloads, bytes32(0), salt);
    }

    function test_RevertWhen_Initialize_ZeroAdmin() public {
        ArxTimelock impl = new ArxTimelock();
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        address[] memory executors = new address[](1);
        executors[0] = executor;

        bytes memory data = abi.encodeWithSelector(
            ArxTimelock.initialize.selector,
            minDelay,
            proposers,
            executors,
            address(0) // Zero admin
        );
        vm.expectRevert(ArxTimelock.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), data);
    }

    function test_RevertWhen_Initialize_ZeroDelay() public {
        ArxTimelock impl = new ArxTimelock();
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        address[] memory executors = new address[](1);
        executors[0] = executor;

        bytes memory data = abi.encodeWithSelector(
            ArxTimelock.initialize.selector,
            0, // Zero delay
            proposers,
            executors,
            admin
        );
        vm.expectRevert(ArxTimelock.InvalidDelay.selector);
        new ERC1967Proxy(address(impl), data);
    }

    function test_RevertWhen_Initialize_EmptyProposers() public {
        ArxTimelock impl = new ArxTimelock();
        address[] memory proposers = new address[](0); // Empty
        address[] memory executors = new address[](1);
        executors[0] = executor;

        bytes memory data = abi.encodeWithSelector(
            ArxTimelock.initialize.selector,
            minDelay,
            proposers,
            executors,
            admin
        );
        vm.expectRevert(ArxTimelock.EmptyArray.selector);
        new ERC1967Proxy(address(impl), data);
    }

    function test_RevertWhen_Initialize_EmptyExecutors() public {
        ArxTimelock impl = new ArxTimelock();
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        address[] memory executors = new address[](0); // Empty

        bytes memory data = abi.encodeWithSelector(
            ArxTimelock.initialize.selector,
            minDelay,
            proposers,
            executors,
            admin
        );
        vm.expectRevert(ArxTimelock.EmptyArray.selector);
        new ERC1967Proxy(address(impl), data);
    }

    function test_Cancel() public {
        address[] memory targets = new address[](1);
        targets[0] = address(target);
        uint256[] memory values = new uint256[](1);
        bytes[] memory payloads = new bytes[](1);
        bytes32 salt = keccak256("test");

        bytes32 id = timelock.hashOperationBatch(
            targets,
            values,
            payloads,
            bytes32(0),
            salt
        );
        vm.prank(proposer);
        timelock.scheduleBatch(
            targets,
            values,
            payloads,
            bytes32(0),
            salt,
            minDelay
        );

        // Cancel - proposer has CANCELLER_ROLE (granted in setUp)
        vm.prank(proposer);
        timelock.cancel(id);

        // Check if operation is canceled - canceled operations have timestamp = 1
        // or we can check isOperationCanceled if available, otherwise check timestamp
        uint256 timestamp = timelock.getTimestamp(id);
        assertTrue(timestamp == 1 || timelock.isOperationPending(id) == false);
    }
}
