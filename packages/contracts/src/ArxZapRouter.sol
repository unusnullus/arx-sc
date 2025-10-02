// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
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

/// @title ArxZapRouter
/// @notice Zaps ERC-20 or ETH into USDC via Uniswap V3, then buys ARX for a buyer in a single transaction.
/// @dev Approvals are reset using OZ v5 SafeERC20.forceApprove to avoid non-standard ERC-20 issues.
contract ArxZapRouter is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice USDC token used by the sale (6 decimals expected).
    IERC20 public immutable USDC;
    /// @notice WETH9 contract for wrapping/unwrapping native ETH.
    IWETH9 public immutable WETH9;
    /// @notice Uniswap V3 swap router.
    ISwapRouter public immutable swapRouter;
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
    constructor(address _owner, IERC20 _usdc, IWETH9 _weth9, ISwapRouter _router) Ownable(_owner) {
        if (address(_usdc) == address(0) || address(_weth9) == address(0) || address(_router) == address(0)) {
            revert ZeroAddress();
        }
        USDC = _usdc;
        WETH9 = _weth9;
        swapRouter = _router;
    }

    /// @notice Set the sale contract used for final ARX purchase.
    function setSale(IArxTokenSale _sale) external onlyOwner {
        if (address(_sale) == address(0)) revert ZeroAddress();
        sale = _sale;
    }

    function _resetAndApprove(IERC20 token, address spender, uint256 amount) internal {
        // If token supports forceApprove (OZ v5 SafeERC20), use it; otherwise fallback
        try token.forceApprove(spender, 0) {} catch {
            token.approve(spender, 0);
        }
        try token.forceApprove(spender, amount) {} catch {
            token.approve(spender, amount);
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
    ) external nonReentrant {
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
    ) external payable nonReentrant {
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
}
// Removed in minimal setup (zap router not used)
