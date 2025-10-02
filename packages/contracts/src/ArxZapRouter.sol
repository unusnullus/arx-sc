// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Minimal interface to interact with the sale contract.
interface IArxTokenSale {
    function buyFor(address buyer, uint256 usdcAmount) external;
    function USDC() external view returns (IERC20);
}

/// @notice Uniswap V3 swap router interface (exactInput).
interface ISwapRouter {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}

/// @notice Minimal WETH9 interface.
interface IWETH9 is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

/// @title ArxZapRouter
/// @notice Zaps ERC-20 or ETH into USDC via Uniswap V3, then buys ARX for a buyer in a single transaction.
/// @dev Approvals are reset using OZ v5 SafeERC20.forceApprove to avoid non-standard ERC-20 issues.
contract ArxZapRouter is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice USDC token used by the sale (6 decimals expected).
    IERC20 public USDC;
    /// @notice WETH9 contract for wrapping/unwrapping native ETH.
    IWETH9 public WETH9;
    /// @notice Uniswap V3 swap router.
    ISwapRouter public swapRouter;
    /// @notice ARX sale contract.
    IArxTokenSale public sale;

    /// @notice Emitted when a zap finishes and ARX is purchased.
    event Zapped(address indexed buyer, address indexed tokenIn, uint256 amountIn, uint256 usdcOut);

    error ZeroAddress();
    error ZeroAmount();

    /// @param _owner Owner address allowed to set sale.
    /// @param _usdc USDC token address.
    /// @param _weth9 WETH9 token address.
    /// @param _router Uniswap V3 swap router address.
    function initialize(address _owner, IERC20 _usdc, IWETH9 _weth9, ISwapRouter _router) public initializer {
        if (address(_usdc) == address(0) || address(_weth9) == address(0) || address(_router) == address(0)) {
            revert ZeroAddress();
        }
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        USDC = _usdc;
        WETH9 = _weth9;
        swapRouter = _router;
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    /// @notice Set the sale contract used for final ARX purchase.
    function setSale(IArxTokenSale _sale) external onlyOwner {
        if (address(_sale) == address(0)) revert ZeroAddress();
        sale = _sale;
    }

    function _resetAndApprove(IERC20 token, address spender, uint256 amount) internal {
        uint256 current = token.allowance(address(this), spender);
        if (current < amount) {
            if (current > 0) {
                token.forceApprove(spender, 0);
            }
            token.forceApprove(spender, amount);
        }
    }

    /// @notice Zap `tokenIn` to USDC via Uniswap V3 and buy ARX for `buyer`.
    /// @param tokenIn Input ERC-20 token address.
    /// @param amountIn Amount of `tokenIn` to swap.
    /// @param path Uniswap V3 path (encoded token/fee hops) ending in USDC.
    /// @param minUsdcOut Minimum acceptable USDC amount to protect against slippage.
    /// @param buyer Final ARX recipient.
    /// @param deadline Unix timestamp after which the swap should revert.
    function zapERC20AndBuy(
        IERC20 tokenIn,
        uint256 amountIn,
        bytes calldata path,
        uint256 minUsdcOut,
        address buyer,
        uint256 deadline
    ) external whenNotPaused nonReentrant {
        if (amountIn == 0) revert ZeroAmount();
        // Pull tokenIn from user
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        // Approve router
        _resetAndApprove(tokenIn, address(swapRouter), amountIn);
        // Swap to USDC
        uint256 usdcOut = swapRouter.exactInput(
            ISwapRouter.ExactInputParams({
                path: path,
                recipient: address(this),
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: minUsdcOut
            })
        );
        // Approve sale and buy ARX for buyer
        _resetAndApprove(USDC, address(sale), usdcOut);
        sale.buyFor(buyer, usdcOut);
        emit Zapped(buyer, address(tokenIn), amountIn, usdcOut);
    }

    function zapERC20WithPermitAndBuy(
        IERC20 tokenIn,
        uint256 amountIn,
        bytes calldata path,
        uint256 minUsdcOut,
        address buyer,
        uint256 deadline,
        address owner,
        uint256 permitValue,
        uint256 permitDeadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenNotPaused nonReentrant {
        if (amountIn == 0) revert ZeroAmount();
        IERC20Permit(address(tokenIn)).permit(owner, address(this), permitValue, permitDeadline, v, r, s);
        tokenIn.safeTransferFrom(owner, address(this), amountIn);
        _resetAndApprove(tokenIn, address(swapRouter), amountIn);
        uint256 usdcOut = swapRouter.exactInput(
            ISwapRouter.ExactInputParams({
                path: path,
                recipient: address(this),
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: minUsdcOut
            })
        );
        _resetAndApprove(USDC, address(sale), usdcOut);
        sale.buyFor(buyer, usdcOut);
        emit Zapped(buyer, address(tokenIn), amountIn, usdcOut);
    }

    /// @notice Zap native ETH to USDC via Uniswap V3 and buy ARX for `buyer`.
    /// @param pathFromWETH Path starting from WETH9 to USDC.
    /// @param minUsdcOut Minimum acceptable USDC out.
    /// @param buyer Final ARX recipient.
    /// @param deadline Deadline timestamp.
    function zapETHAndBuy(
        bytes calldata pathFromWETH,
        uint256 minUsdcOut,
        address buyer,
        uint256 deadline
    ) external payable whenNotPaused nonReentrant {
        uint256 amountIn = msg.value;
        if (amountIn == 0) revert ZeroAmount();
        // Wrap ETH -> WETH9
        WETH9.deposit{ value: amountIn }();
        // Approve router
        _resetAndApprove(IERC20(address(WETH9)), address(swapRouter), amountIn);
        // Swap to USDC
        uint256 usdcOut = swapRouter.exactInput(
            ISwapRouter.ExactInputParams({
                path: pathFromWETH,
                recipient: address(this),
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: minUsdcOut
            })
        );
        // Approve sale and buy ARX for buyer
        _resetAndApprove(USDC, address(sale), usdcOut);
        sale.buyFor(buyer, usdcOut);
        emit Zapped(buyer, address(0), amountIn, usdcOut);
    }

    receive() external payable {}

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
// Removed in minimal setup (zap router not used)
