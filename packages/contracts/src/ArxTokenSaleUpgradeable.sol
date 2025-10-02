// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IARXLike {
    function mint(address to, uint256 amount) external;
}

/// @title ArxTokenSale (Upgradeable)
contract ArxTokenSaleUpgradeable is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 public USDC;
    IARXLike public ARX;
    address public silo;
    uint256 public priceUSDC;
    mapping(address => bool) public zappers;

    event Purchased(address indexed buyer, uint256 usdcAmount, uint256 arxAmount);
    event PriceSet(uint256 priceUSDC);
    event SiloSet(address silo);
    event ZapperSet(address indexed zapper, bool allowed);

    error ZeroAddress();
    error ZeroAmount();
    error NotZapper();

    function initialize(address _owner, IERC20 _usdc, IARXLike _arx, address _silo, uint256 _priceUSDC) public initializer {
        if (address(_usdc) == address(0) || address(_arx) == address(0) || _silo == address(0)) revert ZeroAddress();
        if (_priceUSDC == 0) revert ZeroAmount();
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        USDC = _usdc;
        ARX = _arx;
        silo = _silo;
        priceUSDC = _priceUSDC;
        emit PriceSet(_priceUSDC);
        emit SiloSet(_silo);
    }

    function setPriceUSDC(uint256 _priceUSDC) external onlyOwner {
        if (_priceUSDC == 0) revert ZeroAmount();
        priceUSDC = _priceUSDC;
        emit PriceSet(_priceUSDC);
    }

    function setSilo(address _silo) external onlyOwner {
        if (_silo == address(0)) revert ZeroAddress();
        silo = _silo;
        emit SiloSet(_silo);
    }

    function setZapper(address zapper, bool allowed) external onlyOwner {
        zappers[zapper] = allowed;
        emit ZapperSet(zapper, allowed);
    }

    function buyWithUSDC(uint256 usdcAmount) external nonReentrant {
        if (usdcAmount == 0) revert ZeroAmount();
        USDC.safeTransferFrom(msg.sender, silo, usdcAmount);
        uint256 arxAmount = (usdcAmount * 1e18) / priceUSDC;
        ARX.mint(msg.sender, arxAmount);
        emit Purchased(msg.sender, usdcAmount, arxAmount);
    }

    function buyFor(address buyer, uint256 usdcAmount) external nonReentrant {
        if (!zappers[msg.sender]) revert NotZapper();
        if (usdcAmount == 0) revert ZeroAmount();
        USDC.safeTransferFrom(msg.sender, silo, usdcAmount);
        uint256 arxAmount = (usdcAmount * 1e18) / priceUSDC;
        ARX.mint(buyer, arxAmount);
        emit Purchased(buyer, usdcAmount, arxAmount);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}


