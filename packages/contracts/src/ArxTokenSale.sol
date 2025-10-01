// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IARX } from "./ARX.sol";

contract ArxTokenSale is Ownable, ReentrancyGuard {
    IERC20 public immutable USDC; // 6 decimals
    IARX public immutable ARX;

    address public silo;
    uint256 public priceUSDC; // 6 decimals price per 1 ARX (1e18)

    mapping(address => bool) public zappers;

    event Purchased(address indexed buyer, uint256 usdcAmount, uint256 arxAmount);
    event PriceSet(uint256 priceUSDC);
    event SiloSet(address silo);
    event ZapperSet(address indexed zapper, bool allowed);

    error ZeroAddress();
    error ZeroAmount();
    error NotZapper();

    constructor(address _owner, IERC20 _usdc, IARX _arx, address _silo, uint256 _priceUSDC)
        Ownable(_owner)
    {
        if (address(_usdc) == address(0) || address(_arx) == address(0) || _silo == address(0)) {
            revert ZeroAddress();
        }
        if (_priceUSDC == 0) revert ZeroAmount();
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
        // Pull USDC from buyer
        require(USDC.transferFrom(msg.sender, silo, usdcAmount), "USDC transfer failed");
        // Mint ARX to buyer: arx = usdc * 1e18 / priceUSDC
        uint256 arxAmount = (usdcAmount * 1e18) / priceUSDC;
        ARX.mint(msg.sender, arxAmount);
        emit Purchased(msg.sender, usdcAmount, arxAmount);
    }

    function buyFor(address buyer, uint256 usdcAmount) external nonReentrant {
        if (!zappers[msg.sender]) revert NotZapper();
        if (usdcAmount == 0) revert ZeroAmount();
        require(USDC.transferFrom(msg.sender, silo, usdcAmount), "USDC transfer failed");
        uint256 arxAmount = (usdcAmount * 1e18) / priceUSDC;
        ARX.mint(buyer, arxAmount);
        emit Purchased(buyer, usdcAmount, arxAmount);
    }
}
