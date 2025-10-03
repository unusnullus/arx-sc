// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title StakingAccess
/// @notice Upgradeable staking contract for ARX (6 decimals) that computes access tiers.
/// @dev
/// - UUPS upgradeable; admin is expected to be a Timelock/Multisig.
/// - Tier thresholds are provided as an ascending array at initialization and can
///   be updated by the owner (governance).
/// - Unstaking is two-step: request then claim after a 30-day cooldown. Pending
///   unstakes do not count toward a user's tier.
contract StakingAccess is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    /// @notice ARX token being staked (6 decimals).
    IERC20 public ARX; // 6 decimals token

    // Tier thresholds in ARX units (6 decimals), ascending order
    /// @notice Ascending tier thresholds, denominated in ARX base units (6 decimals).
    /// @dev Example: [1_000_000, 10_000_000, 100_000_000] for 1/10/100 ARX.
    uint256[] public tiers; // e.g., [1e6, 10e6, 100e6]

    // Active staked balances (counted towards tier)
    /// @notice Active staked balances counted toward tier.
    mapping(address => uint256) public staked;

    // Pending unstakes subject to cooldown
    /// @notice Pending unstake info for a user.
    struct Pending {
        /// @dev Amount requested to unstake, awaiting cooldown expiry.
        uint256 amount;
        /// @dev Timestamp when `amount` becomes claimable.
        uint256 availableAt;
    }

    /// @notice Unstake requests per user.
    mapping(address => Pending) public pendingUnstake;

    // Cooldown period for unstake requests (1 month)
    /// @notice Cooldown period for unstake requests (30 days).
    uint256 public constant UNSTAKE_COOLDOWN = 30 days;

    /// @notice Emitted when `user` stakes `amount` ARX.
    event Staked(address indexed user, uint256 amount);
    /// @notice Emitted when `user` requests to unstake `amount`, claimable at `availableAt`.
    event UnstakeRequested(address indexed user, uint256 amount, uint256 availableAt);
    /// @notice Emitted when `user` claims a previously requested unstake of `amount`.
    event UnstakeClaimed(address indexed user, uint256 amount);
    /// @notice Emitted when tier thresholds are updated.
    event TiersUpdated(uint256[] tiers);

    /// @notice Zero address provided.
    error ZeroAddress();
    /// @notice Zero amount provided where non-zero is required.
    error ZeroAmount();
    /// @notice Not enough staked balance to perform the action.
    error InsufficientStake();
    /// @notice There is no pending unstake to claim.
    error NothingToClaim();
    /// @notice Unstake cooldown has not elapsed.
    /// @param availableAt Timestamp when claim becomes available.
    /// @param nowTs Current block timestamp.
    error CooldownNotElapsed(uint256 availableAt, uint256 nowTs);
    /// @notice Tier thresholds array is invalid (empty, non-ascending, or zero values).
    error InvalidTiers();

    /// @notice Initialize the staking contract.
    /// @param arx ARX token (6 decimals) to stake.
    /// @param owner_ Initial owner (governance admin, e.g., Timelock/Multisig).
    /// @param _tiers Ascending tier thresholds in ARX base units.
    function initialize(IERC20 arx, address owner_, uint256[] memory _tiers) public initializer {
        if (address(arx) == address(0) || owner_ == address(0)) revert ZeroAddress();
        __Ownable_init(owner_);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        ARX = arx;
        _setTiers(_tiers);
    }

    /// @notice Update tier thresholds (governance only).
    /// @param _tiers Ascending thresholds in ARX base units (6 decimals).
    function setTiers(uint256[] calldata _tiers) external onlyOwner {
        _setTiers(_tiers);
    }

    /// @dev Validate and store tier thresholds.
    function _setTiers(uint256[] memory _tiers) internal {
        // Allow zero-length to disable tiers? For now, require at least one tier.
        if (_tiers.length == 0) revert InvalidTiers();
        // Ensure strictly ascending order and non-zero values
        for (uint256 i = 0; i < _tiers.length; i++) {
            if (_tiers[i] == 0) revert InvalidTiers();
            if (i > 0 && _tiers[i] <= _tiers[i - 1]) revert InvalidTiers();
        }
        tiers = _tiers;
        emit TiersUpdated(_tiers);
    }

    /// @notice Stake `amount` of ARX.
    /// @param amount Amount of ARX to stake (6 decimals).
    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        staked[msg.sender] += amount;
        ARX.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /// @notice Begin the unstake process; tokens become claimable after a 30-day cooldown.
    /// @param amount Amount of ARX to request for unstake (6 decimals).
    function requestUnstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 bal = staked[msg.sender];
        if (bal < amount) revert InsufficientStake();
        staked[msg.sender] = bal - amount;
        Pending storage p = pendingUnstake[msg.sender];
        p.amount += amount;
        uint256 unlock = block.timestamp + UNSTAKE_COOLDOWN;
        if (unlock > p.availableAt) {
            p.availableAt = unlock;
        }
        emit UnstakeRequested(msg.sender, amount, p.availableAt);
    }

    /// @notice Claim tokens after the cooldown has elapsed.
    function claimUnstaked() external nonReentrant {
        Pending storage p = pendingUnstake[msg.sender];
        uint256 amount = p.amount;
        if (amount == 0) revert NothingToClaim();
        uint256 availableAt = p.availableAt;
        if (block.timestamp < availableAt) revert CooldownNotElapsed(availableAt, block.timestamp);
        p.amount = 0;
        // keep availableAt as-is (historical), or reset to 0 for clarity
        p.availableAt = 0;
        ARX.safeTransfer(msg.sender, amount);
        emit UnstakeClaimed(msg.sender, amount);
    }

    /// @notice Compute tier of `user` based on currently staked ARX (excludes pending unstakes).
    /// @param user Address to query.
    /// @return tierIndex Tier index starting at 0 for below first tier; otherwise equals number of thresholds met.
    function tierOf(address user) public view returns (uint8 tierIndex) {
        uint256 s = staked[user];
        uint256 len = tiers.length;
        for (uint256 i = 0; i < len; i++) {
            if (s < tiers[i]) {
                return uint8(i);
            }
        }
        return uint8(len);
    }

    /// @dev UUPS upgrade authorization; restricted to owner (governance).
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
