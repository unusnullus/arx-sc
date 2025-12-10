// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    PausableUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ARX} from "../token/ARX.sol";

/**
 * @title ARX/USDC Price-Based Pool
 * @notice AMM where execution uses ARX price from token sale contract (USDC assumed 1:1 USD).
 * Liquidity accounting and LP minting are done by USD value contribution to keep
 * fair shares even with price-based execution (not AMM formula).
 */
contract ARXPool is
    Initializable,
    ERC20Upgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    uint256 internal constant MAX_FEE = 500; // in bps
    uint256 internal constant BASIS_POINTS = 10_000;
    uint256 internal constant ARX_SCALE = 1_000_000; // 1 ARX (6 decimals)

    uint16 public swapFee; // in bps

    ARX public arx;
    IERC20 public arxToken; // IERC20 interface for SafeERC20 operations
    IERC20 public usdc;

    error ZeroAddress();
    error ZeroAmount();
    error InvalidPair();
    error FeeTooHigh();
    error EmptyPool();
    error Slippage();
    error PriceContractsNotInitialized();

    event LiquidityAdded(
        address indexed user,
        uint256 arxAmount,
        uint256 usdcAmount,
        uint256 lpTokens
    );
    event LiquidityRemoved(
        address indexed user,
        uint256 lpTokens,
        uint256 arxAmount,
        uint256 usdcAmount
    );
    event Swapped(
        address indexed user,
        address indexed inToken,
        uint256 inAmount,
        uint256 outAmount
    );
    event FeeUpdated(uint256 oldFee, uint256 newFee);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the pool
    /// @param _arx Address of ARX token
    /// @param _usdc Address of USDC token
    /// @param _owner Owner address with admin privileges
    function initialize(
        address _arx,
        address _usdc,
        address _owner
    ) public initializer {
        if (_arx == address(0) || _usdc == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }
        __ERC20_init("ARX/USDC LP", "ARX-USDC-LP");
        __Pausable_init();
        __Ownable_init(_owner);
        arx = ARX(_arx);
        arxToken = IERC20(_arx);
        usdc = IERC20(_usdc);
        swapFee = 50; // 0.5% default fee
    }

    /// @notice Get current reserves of both tokens
    /// @return reserveARX Current ARX balance in the pool
    /// @return reserveUSDC Current USDC balance in the pool
    function getReserves()
        public
        view
        returns (uint256 reserveARX, uint256 reserveUSDC)
    {
        reserveARX = arx.balanceOf(address(this));
        reserveUSDC = usdc.balanceOf(address(this));
    }

    // ---------- Pricing ----------

    /// @notice Get ARX price in USDC using ARX token's price from sale contract
    /// @param arxAmount Amount of ARX to price
    /// @return usdcValue Equivalent USDC value
    function _arxPriceInUSDC(
        uint256 arxAmount
    ) internal view returns (uint256) {
        if (arxAmount == 0) return 0;
        return arx.getArxPriceInToken(address(usdc), arxAmount);
    }

    /// @notice Get adjusted price for the trading pair
    /// @param baseToken Base token address (ARX or USDC)
    /// @param quoteToken Quote token address (USDC or ARX)
    /// @return price Price of baseToken in quoteToken units
    function getAdjustedPrice(
        address baseToken,
        address quoteToken
    ) external view returns (uint256) {
        if (
            !((baseToken == address(arx) && quoteToken == address(usdc)) ||
                (baseToken == address(usdc) && quoteToken == address(arx)))
        ) {
            revert InvalidPair();
        }
        if (baseToken == address(arx)) {
            // Price of 1 ARX in USDC (6 decimals)
            return _arxPriceInUSDC(ARX_SCALE);
        } else {
            // Price of 1 USDC in ARX units
            return arx.getTokenToArxExchangeRate(address(usdc), ARX_SCALE);
        }
    }

    // ---------- Liquidity (USD-based shares) ----------

    /// @notice Calculate USD value of provided amounts
    /// @param arxAmount Amount of ARX
    /// @param usdcAmount Amount of USDC
    /// @return usdValue Total USD value in USDC units (6 decimals)
    function _usdValue(
        uint256 arxAmount,
        uint256 usdcAmount
    ) internal view returns (uint256) {
        return _arxPriceInUSDC(arxAmount) + usdcAmount; // both in USDC units (6)
    }

    /// @notice Add liquidity to the pool
    /// @param arxDesired Desired amount of ARX to add
    /// @param usdcDesired Desired amount of USDC to add
    /// @return arxAdded Actual amount of ARX added
    /// @return usdcAdded Actual amount of USDC added
    /// @return lpMinted Amount of LP tokens minted
    function addLiquidity(
        uint256 arxDesired,
        uint256 usdcDesired
    )
        external
        whenNotPaused
        returns (uint256 arxAdded, uint256 usdcAdded, uint256 lpMinted)
    {
        if (arxDesired == 0 && usdcDesired == 0) {
            revert ZeroAmount();
        }

        (uint256 rA, uint256 rU) = getReserves();
        uint256 ts = totalSupply();

        if (arxDesired == 0 || usdcDesired == 0) {
            // Single-sided add: accept provided side as-is
            arxAdded = arxDesired;
            usdcAdded = usdcDesired;

            if (arxAdded > 0) {
                arxToken.safeTransferFrom(msg.sender, address(this), arxAdded);
            }
            if (usdcAdded > 0) {
                usdc.safeTransferFrom(msg.sender, address(this), usdcAdded);
            }

            uint256 usdAdded = _usdValue(arxAdded, usdcAdded);
            if (ts == 0) {
                // first LP: mint by USD value directly
                lpMinted = usdAdded;
            } else {
                uint256 usdPool = _usdValue(rA, rU);
                lpMinted = (usdAdded * ts) / usdPool;
            }
        } else {
            // Dual-sided: trim to sale price ratio
            uint256 arxPrice = _arxPriceInUSDC(ARX_SCALE); // USDC per 1 ARX
            uint256 requiredU = (arxDesired * arxPrice) / ARX_SCALE;
            if (requiredU <= usdcDesired) {
                arxAdded = arxDesired;
                usdcAdded = requiredU;
            } else {
                arxAdded = (usdcDesired * ARX_SCALE) / arxPrice;
                usdcAdded = usdcDesired;
            }

            arxToken.safeTransferFrom(msg.sender, address(this), arxAdded);
            usdc.safeTransferFrom(msg.sender, address(this), usdcAdded);

            uint256 usdAdded = _usdValue(arxAdded, usdcAdded);
            if (ts == 0) {
                lpMinted = usdAdded;
            } else {
                uint256 usdPool = _usdValue(rA, rU);
                lpMinted = (usdAdded * ts) / usdPool;
            }
        }

        if (lpMinted == 0) {
            revert ZeroAmount();
        }
        _mint(msg.sender, lpMinted);
        emit LiquidityAdded(msg.sender, arxAdded, usdcAdded, lpMinted);
    }

    /// @notice Remove liquidity from the pool
    /// @param lpAmount Amount of LP tokens to burn
    /// @return arxReturned Amount of ARX returned
    /// @return usdcReturned Amount of USDC returned
    function removeLiquidity(
        uint256 lpAmount
    )
        external
        whenNotPaused
        returns (uint256 arxReturned, uint256 usdcReturned)
    {
        if (lpAmount == 0) {
            revert ZeroAmount();
        }
        uint256 ts = totalSupply();
        (uint256 rA, uint256 rU) = getReserves();
        if (rA == 0 && rU == 0) {
            revert EmptyPool();
        }

        arxReturned = (rA * lpAmount) / ts;
        usdcReturned = (rU * lpAmount) / ts;

        _burn(msg.sender, lpAmount);
        if (arxReturned > 0) {
            arxToken.safeTransfer(msg.sender, arxReturned);
        }
        if (usdcReturned > 0) {
            usdc.safeTransfer(msg.sender, usdcReturned);
        }
        emit LiquidityRemoved(msg.sender, lpAmount, arxReturned, usdcReturned);
    }

    // ---------- Swaps (price-based exact-in) ----------

    /// @notice Swap exact ARX for USDC
    /// @param arxAmountIn Amount of ARX to swap
    /// @param minUSDCOut Minimum USDC amount expected (slippage protection)
    function swapExactARXToUSDC(
        uint256 arxAmountIn,
        uint256 minUSDCOut
    ) external whenNotPaused {
        if (arxAmountIn == 0) {
            revert ZeroAmount();
        }
        (, uint256 rU) = getReserves();
        uint256 amountInWithFee = (arxAmountIn * (BASIS_POINTS - swapFee)) /
            BASIS_POINTS;
        uint256 quote = _arxPriceInUSDC(amountInWithFee);
        uint256 usdcOut = quote > rU ? rU : quote; // can't exceed reserves
        if (usdcOut < minUSDCOut || usdcOut == 0) {
            revert Slippage();
        }
        arxToken.safeTransferFrom(msg.sender, address(this), arxAmountIn);
        usdc.safeTransfer(msg.sender, usdcOut);
        emit Swapped(msg.sender, address(arx), arxAmountIn, usdcOut);
    }

    /// @notice Swap exact USDC for ARX
    /// @param usdcAmountIn Amount of USDC to swap
    /// @param minARXOut Minimum ARX amount expected (slippage protection)
    function swapExactUSDCToARX(
        uint256 usdcAmountIn,
        uint256 minARXOut
    ) external whenNotPaused {
        if (usdcAmountIn == 0) {
            revert ZeroAmount();
        }
        (uint256 rA, ) = getReserves();
        uint256 amountInWithFee = (usdcAmountIn * (BASIS_POINTS - swapFee)) /
            BASIS_POINTS;
        uint256 arxOut = arx.getTokenToArxExchangeRate(
            address(usdc),
            amountInWithFee
        );
        if (arxOut > rA) {
            arxOut = rA;
        }
        if (arxOut < minARXOut || arxOut == 0) {
            revert Slippage();
        }
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmountIn);
        arxToken.safeTransfer(msg.sender, arxOut);
        emit Swapped(msg.sender, address(usdc), usdcAmountIn, arxOut);
    }

    // ---------- Admin ----------

    /// @notice Update swap fee
    /// @param newFee New fee in basis points (max 500 = 5%)
    function setSwapFee(uint16 newFee) external onlyOwner {
        if (newFee > MAX_FEE) {
            revert FeeTooHigh();
        }
        uint256 old = swapFee;
        swapFee = newFee;
        emit FeeUpdated(old, newFee);
    }

    /// @notice Pause the pool
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the pool
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Authorize upgrade (UUPS pattern)
    function _authorizeUpgrade(address) internal override onlyOwner {}

    // ---------- Metadata ----------

    /// @notice LP token uses 6 decimals (matching ARX and USDC)
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // ---------- Preview/View helpers ----------

    /// @notice Preview what amounts will actually be added and LP minted
    /// @dev Same logic as addLiquidity but view-only (no state changes)
    /// @param arxDesired Desired amount of ARX to add
    /// @param usdcDesired Desired amount of USDC to add
    /// @return arxToAdd Actual amount of ARX that would be added
    /// @return usdcToAdd Actual amount of USDC that would be added
    /// @return lpToMint Amount of LP tokens that would be minted
    function previewAddLiquidity(
        uint256 arxDesired,
        uint256 usdcDesired
    )
        external
        view
        returns (uint256 arxToAdd, uint256 usdcToAdd, uint256 lpToMint)
    {
        if (arxDesired == 0 && usdcDesired == 0) {
            revert ZeroAmount();
        }

        (uint256 rA, uint256 rU) = getReserves();
        uint256 ts = totalSupply();

        if (arxDesired == 0 || usdcDesired == 0) {
            // Single-sided
            arxToAdd = arxDesired;
            usdcToAdd = usdcDesired;

            uint256 usdAdded = _usdValue(arxToAdd, usdcToAdd);
            if (ts == 0) {
                lpToMint = usdAdded;
            } else {
                uint256 usdPool = _usdValue(rA, rU);
                lpToMint = (usdAdded * ts) / usdPool;
            }
        } else {
            // Dual-sided: trim to sale price ratio
            uint256 arxPrice = _arxPriceInUSDC(ARX_SCALE);
            uint256 requiredU = (arxDesired * arxPrice) / ARX_SCALE;
            if (requiredU <= usdcDesired) {
                arxToAdd = arxDesired;
                usdcToAdd = requiredU;
            } else {
                arxToAdd = (usdcDesired * ARX_SCALE) / arxPrice;
                usdcToAdd = usdcDesired;
            }

            uint256 usdAdded = _usdValue(arxToAdd, usdcToAdd);
            if (ts == 0) {
                lpToMint = usdAdded;
            } else {
                uint256 usdPool = _usdValue(rA, rU);
                lpToMint = (usdAdded * ts) / usdPool;
            }
        }
    }
}
