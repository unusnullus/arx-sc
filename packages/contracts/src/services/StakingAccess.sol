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
/// @notice Stake ARX (6 decimals) to gain access tiers used by ServiceRegistry.
contract StakingAccess is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    IERC20 public ARX; // 6 decimals token

    // Tier thresholds in ARX units (6 decimals), ascending order
    uint256[] public tiers; // e.g., [1e6, 10e6, 100e6]

    // Active staked balances (counted towards tier)
    mapping(address => uint256) public staked;

    // Pending unstakes subject to cooldown
    struct Pending {
        uint256 amount;
        uint256 availableAt;
    }
    mapping(address => Pending) public pendingUnstake;

    // Cooldown period for unstake requests (1 month)
    uint256 public constant UNSTAKE_COOLDOWN = 30 days;

    event Staked(address indexed user, uint256 amount);
    event UnstakeRequested(address indexed user, uint256 amount, uint256 availableAt);
    event UnstakeClaimed(address indexed user, uint256 amount);
    event TiersUpdated(uint256[] tiers);

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientStake();
    error NothingToClaim();
    error CooldownNotElapsed(uint256 availableAt, uint256 nowTs);
    error InvalidTiers();

    function initialize(IERC20 arx, address owner_, uint256[] memory _tiers) public initializer {
        if (address(arx) == address(0) || owner_ == address(0)) revert ZeroAddress();
        __Ownable_init(owner_);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        ARX = arx;
        _setTiers(_tiers);
    }

    function setTiers(uint256[] calldata _tiers) external onlyOwner {
        _setTiers(_tiers);
    }

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

    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        staked[msg.sender] += amount;
        ARX.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /// @notice Begin unstake process; tokens become claimable after a 30-day cooldown.
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

    /// @notice Claim tokens after cooldown.
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
    /// @return tierIndex Tier index starting at 0 for below first tier; otherwise equals number of thresholds met
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

    function _authorizeUpgrade(address) internal override onlyOwner { }
}
