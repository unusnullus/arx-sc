// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { TimelockControllerUpgradeable } from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/// @title ArxTimelock
/// @notice Upgradeable timelock controller for ARX governance.
contract ArxTimelock is Initializable, TimelockControllerUpgradeable, UUPSUpgradeable {
    /// @notice Initialize the timelock with delay, proposers, executors and admin.
    /// @param minDelay Minimum delay (in seconds) before an operation can be executed.
    /// @param proposers Array of addresses allowed to propose operations.
    /// @param executors Array of addresses allowed to execute operations.
    /// @param admin Address that will be granted DEFAULT_ADMIN_ROLE.
    function initialize(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) public override initializer {
        __TimelockController_init(minDelay, proposers, executors, admin);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
