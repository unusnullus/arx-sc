// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {
    PausableUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IARX} from "../token/IARX.sol";
import {
    IERC20Metadata
} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title ArxTokenSale
/// @notice USDC-denominated token sale for ARX token.
/// @dev Accepts USDC (6 decimals), forwards 100% of USDC to `silo` treasury,
///      and mints ARX to the buyer using priceUSDC (6 decimals per 1e18 ARX).
contract ArxTokenSale is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    /// @notice USDC token used for purchases (6 decimals).

    IERC20 public USDC; // 6 decimals
    /// @notice ARX token to mint to buyers on successful purchase.
    IARX public ARX;
    /// @notice Decimals of ARX token used in pricing conversion.
    uint8 public arxDecimals;

    /// @notice Treasury address that receives 100% of USDC paid by buyers.
    address public silo;
    /// @notice 6-decimal USDC price per 1e18 ARX. Example: 5 USDC = 5_000_000.
    uint256 public priceUSDC; // 6 decimals price per 1 ARX (1e18)

    /// @notice Optional allowlist for zapper contracts that call buyFor().
    mapping(address => bool) public zappers;

    /// @notice Emitted on successful purchase.
    event Purchased(
        address indexed buyer,
        uint256 usdcAmount,
        uint256 arxAmount
    );
    /// @notice Emitted when price is updated.
    event PriceSet(uint256 priceUSDC);
    /// @notice Emitted when silo treasury is updated.
    event SiloSet(address silo);
    /// @notice Emitted when zapper authorization changes.
    event ZapperSet(address indexed zapper, bool allowed);

    error ZeroAddress();
    error ZeroAmount();
    error NotZapper();
    error AmountTooSmall();

    /// @param _owner Owner address with permission to manage sale settings.
    /// @param _usdc Address of USDC token (6 decimals).
    /// @param _arx Address of ARX token implementing IARX.
    /// @param _silo Treasury address that receives all USDC.
    /// @param _priceUSDC 6-decimal USDC price per 1e18 ARX (e.g. 5 USDC = 5_000_000).
    function initialize(
        address _owner,
        IERC20 _usdc,
        IARX _arx,
        address _silo,
        uint256 _priceUSDC
    ) public initializer {
        if (
            _owner == address(0) ||
            address(_usdc) == address(0) ||
            address(_arx) == address(0) ||
            _silo == address(0)
        ) {
            revert ZeroAddress();
        }
        if (_priceUSDC == 0) revert ZeroAmount();
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        USDC = _usdc;
        ARX = _arx;
        arxDecimals = IERC20Metadata(address(_arx)).decimals();
        silo = _silo;
        priceUSDC = _priceUSDC;
        emit PriceSet(_priceUSDC);
        emit SiloSet(_silo);
    }

    /// @notice Update the sale price in USDC (6 decimals per 1e18 ARX).
    /// @param _priceUSDC New price. Reverts if zero.
    function setPriceUSDC(uint256 _priceUSDC) external onlyOwner {
        if (_priceUSDC == 0) revert ZeroAmount();
        priceUSDC = _priceUSDC;
        emit PriceSet(_priceUSDC);
    }

    /// @notice Update the treasury address that receives USDC.
    /// @param _silo New treasury address.
    function setSilo(address _silo) external onlyOwner {
        if (_silo == address(0)) revert ZeroAddress();
        silo = _silo;
        emit SiloSet(_silo);
    }

    /// @notice Authorize or revoke a zapper contract for calling {buyFor}.
    /// @param zapper Zapper contract address.
    /// @param allowed True to authorize, false to revoke.
    function setZapper(address zapper, bool allowed) external onlyOwner {
        if (zapper == address(0)) revert ZeroAddress();
        zappers[zapper] = allowed;
        emit ZapperSet(zapper, allowed);
    }

    /// @notice Pauses the contract, preventing all purchase operations.
    /// @dev This function can only be called by the contract owner. When paused,
    ///      all external functions that modify state will revert, providing an emergency stop mechanism.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract, allowing purchase operations to resume.
    /// @dev This function can only be called by the contract owner. It restores normal
    ///      contract functionality after a pause.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Buy ARX directly by paying USDC. 100% USDC forwarded to `silo`.
    /// @dev Requires prior USDC approval for this contract.
    /// @param usdcAmount Amount of USDC (6 decimals) to spend.
    function buyWithUSDC(
        uint256 usdcAmount
    ) external nonReentrant whenNotPaused {
        if (usdcAmount == 0) revert ZeroAmount();
        uint256 arxAmount = (usdcAmount * (10 ** uint256(arxDecimals))) /
            priceUSDC;
        if (arxAmount == 0) revert AmountTooSmall();
        USDC.safeTransferFrom(msg.sender, silo, usdcAmount);
        ARX.mint(msg.sender, arxAmount);
        emit Purchased(msg.sender, usdcAmount, arxAmount);
    }

    /// @notice Buy ARX for another recipient, callable only by authorized zappers.
    /// @param buyer Recipient to receive ARX.
    /// @param usdcAmount Amount of USDC (6 decimals) to spend.
    function buyFor(
        address buyer,
        uint256 usdcAmount
    ) external nonReentrant whenNotPaused {
        if (!zappers[msg.sender]) revert NotZapper();
        if (buyer == address(0)) revert ZeroAddress();
        if (usdcAmount == 0) revert ZeroAmount();
        uint256 arxAmount = (usdcAmount * (10 ** uint256(arxDecimals))) /
            priceUSDC;
        if (arxAmount == 0) revert AmountTooSmall();
        USDC.safeTransferFrom(msg.sender, silo, usdcAmount);
        ARX.mint(buyer, arxAmount);
        emit Purchased(buyer, usdcAmount, arxAmount);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
