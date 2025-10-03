// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

interface IStakingAccess {
    function tierOf(address user) external view returns (uint8);
}

/// @title ServiceRegistry
/// @notice Upgradeable registry for services gated by staking tiers.
/// @dev
/// - UUPS upgradeable; admin is expected to be a Timelock/Multisig.
/// - Requires users to be EOAs for registration to reduce phishing from contracts.
/// - Uses per-user active counts per service type to enable O(1) reads of enabled types.
contract ServiceRegistry is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    /// @notice Types of services supported by the registry.
    enum ServiceType {
        Relay,
        VPN,
        Merchant,
        C_VPN,
        C_CLOUD,
        C_CARD,
        C_ESIM,
        C_SECURE_MODE,
        C_ULTRA
    }

    /// @notice Staking contract used to validate access tiers.
    IStakingAccess public staking;

    /// @notice Registered service record.
    struct Service {
        /// @dev Owner/registrant of the service.
        address owner;
        /// @dev Type of the service.
        ServiceType serviceType;
        /// @dev Off-chain pointer (URL or JSON blob reference).
        string metadata;
        /// @dev Whether the service is active.
        bool active;
    }

    // serviceId => Service
    /// @notice ServiceId (keccak) to service record.
    mapping(bytes32 => Service) public services;

    // Per-user active counts per service type (to avoid unbounded iteration on reads)
    /// @notice Per-user active service counts by type.
    mapping(address => mapping(ServiceType => uint256)) public activeCounts;

    /// @notice Emitted when a service is registered.
    event ServiceRegistered(
        bytes32 indexed id, address indexed owner, ServiceType serviceType, string metadata
    );
    /// @notice Emitted when a service is updated.
    event ServiceUpdated(bytes32 indexed id, string metadata, bool active);

    /// @notice Zero address provided.
    error ZeroAddress();
    /// @notice Only EOAs may call the function.
    error NotEOA();
    /// @notice Caller is not authorized to perform the action.
    error Unauthorized();

    /// @notice Initialize the registry.
    /// @param staking_ Staking contract used for tier checks.
    /// @param owner_ Initial owner (governance admin, e.g., Timelock/Multisig).
    function initialize(IStakingAccess staking_, address owner_) public initializer {
        if (address(staking_) == address(0) || owner_ == address(0)) revert ZeroAddress();
        __Ownable_init(owner_);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        staking = staking_;
    }

    /// @notice Update staking contract address (governance only).
    /// @param staking_ New staking contract.
    function setStaking(IStakingAccess staking_) external onlyOwner {
        if (address(staking_) == address(0)) revert ZeroAddress();
        staking = staking_;
    }

    /// @notice Register a new service if caller meets tier threshold.
    /// @dev Requires EOA caller to avoid phishing via contracts.
    /// @param serviceType Service type to register.
    /// @param metadata Off-chain metadata pointer.
    function register(ServiceType serviceType, string calldata metadata)
        external
        nonReentrant
        returns (bytes32 id)
    {
        if (msg.sender != tx.origin) revert NotEOA();
        uint8 tier = staking.tierOf(msg.sender);
        require(tier >= 1, "Tier too low");
        // ServiceId is a function of owner, type, and metadata to allow multiple entries per type.
        id = keccak256(abi.encode(msg.sender, serviceType, metadata));
        services[id] = Service({
            owner: msg.sender,
            serviceType: serviceType,
            metadata: metadata,
            active: true
        });
        // Track availability: at least one active service of this type for the user
        unchecked {
            activeCounts[msg.sender][serviceType] += 1;
        }
        emit ServiceRegistered(id, msg.sender, serviceType, metadata);
    }

    /// @notice Update service metadata/active flag; only owner of the service can update.
    /// @param id ServiceId returned at registration.
    /// @param metadata New off-chain metadata pointer.
    /// @param active Whether the service should be active.
    function update(bytes32 id, string calldata metadata, bool active) external nonReentrant {
        Service storage s = services[id];
        if (s.owner != msg.sender) revert Unauthorized();
        bool wasActive = s.active;
        s.metadata = metadata;
        s.active = active;
        if (active != wasActive) {
            if (active) {
                unchecked {
                    activeCounts[msg.sender][s.serviceType] += 1;
                }
            } else {
                // Ensure we don't underflow; safe because update can only be called by owner of an existing service id
                uint256 current = activeCounts[msg.sender][s.serviceType];
                if (current > 0) {
                    activeCounts[msg.sender][s.serviceType] = current - 1;
                }
            }
        }
        emit ServiceUpdated(id, metadata, active);
    }

    /// @notice Return the list of enabled service types for `user` (has at least one active service of that type).
    /// @param user Address to query.
    /// @return enabled Dynamic array of service types enabled for the user.
    function enabledServices(address user) external view returns (ServiceType[] memory enabled) {
        // There are 9 service types in the enum; prepare a temporary array
        ServiceType[9] memory tmp;
        uint256 count;
        // Manually check each enum member; avoids unbounded iteration over stored data
        if (activeCounts[user][ServiceType.Relay] > 0) tmp[count++] = ServiceType.Relay;
        if (activeCounts[user][ServiceType.VPN] > 0) tmp[count++] = ServiceType.VPN;
        if (activeCounts[user][ServiceType.Merchant] > 0) tmp[count++] = ServiceType.Merchant;
        if (activeCounts[user][ServiceType.C_VPN] > 0) tmp[count++] = ServiceType.C_VPN;
        if (activeCounts[user][ServiceType.C_CLOUD] > 0) tmp[count++] = ServiceType.C_CLOUD;
        if (activeCounts[user][ServiceType.C_CARD] > 0) tmp[count++] = ServiceType.C_CARD;
        if (activeCounts[user][ServiceType.C_ESIM] > 0) tmp[count++] = ServiceType.C_ESIM;
        if (activeCounts[user][ServiceType.C_SECURE_MODE] > 0) {
            tmp[count++] = ServiceType.C_SECURE_MODE;
        }
        if (activeCounts[user][ServiceType.C_ULTRA] > 0) tmp[count++] = ServiceType.C_ULTRA;

        enabled = new ServiceType[](count);
        for (uint256 i = 0; i < count; i++) {
            enabled[i] = tmp[i];
        }
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }
}
