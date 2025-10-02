// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Uniswap V3 swap router interface (exactInput).
interface ISwapRouterV3 {
    struct ExactInputParams {
        bytes path;              // token/fee hops encoded per Uniswap spec
        address recipient;       // final recipient of the swapped output
        uint256 deadline;        // timestamp after which tx reverts
        uint256 amountIn;        // exact input amount
        uint256 amountOutMinimum;// slippage protection
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

/// @notice Minimal ERC20Permit interface (EIP-2612).
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

/// @title GenericZapper
/// @notice Protocol-agnostic zapper to swap ERC-20 or native ETH into any output token
///         via Uniswap V3 and deliver the output directly to a recipient.
/// @dev
/// - ERC-20 path: Supports optional EIP-2612 permit to avoid a prior approval.
/// - ETH path: Wraps to WETH9, swaps via Uniswap V3, and sends output to recipient.
/// - Approvals: Uses an allowance check + SafeERC20.forceApprove to minimize gas and
///   handle non-standard ERC-20s safely.
/// - Composability: This contract does not assume any post-swap action; downstream
///   integrations can act on the recipient balance.
contract GenericZapper is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice WETH9 contract used to wrap/unwrap native ETH for swaps.
    IWETH9 public immutable WETH9;
    /// @notice Uniswap V3 router used for swaps.
    ISwapRouterV3 public immutable swapRouter;

    /// @notice Emitted after a successful zap.
    /// @param sender Caller who provided the assets to swap
    /// @param recipient Address that received the final output tokens
    /// @param tokenIn ERC-20 token used as input (address(0) indicates native ETH)
    /// @param amountIn Amount of input provided
    /// @param amountOut Amount of output tokens received by `recipient`
    event Zapped(
        address indexed sender,
        address indexed recipient,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOut
    );

    error ZeroAddress();
    error ZeroAmount();

    /// @param _owner Owner address with permission to update settings if extended.
    /// @param _weth9 Address of WETH9 contract.
    /// @param _router Address of Uniswap V3 swap router.
    constructor(address _owner, IWETH9 _weth9, ISwapRouterV3 _router) Ownable(_owner) {
        if (address(_weth9) == address(0) || address(_router) == address(0)) revert ZeroAddress();
        WETH9 = _weth9;
        swapRouter = _router;
    }

    /// @notice Ensure allowance for `spender` is at least `amount`.
    /// @dev Resets to 0 first when needed and uses SafeERC20.forceApprove to handle
    ///      non-standard tokens. No action taken if current allowance is sufficient.
    function _resetAndApprove(IERC20 token, address spender, uint256 amount) internal {
        uint256 current = token.allowance(address(this), spender);
        if (current < amount) {
            if (current > 0) {
                token.forceApprove(spender, 0);
            }
            token.forceApprove(spender, amount);
        }
    }

    /// @notice Zap ERC-20 into an arbitrary output token via Uniswap V3 with optional EIP-2612 permit.
    /// @dev
    /// - If `permitOwner != address(0)`, a permit is executed first to grant allowance to this contract,
    ///   then tokens are pulled from `permitOwner` via transferFrom. Otherwise tokens are pulled from
    ///   `msg.sender`.
    /// - Output token is determined by the tail of `path` and delivered directly to `recipient`.
    /// @param tokenIn ERC-20 token to swap from.
    /// @param amountIn Exact input amount of `tokenIn` to pull and swap.
    /// @param path Uniswap V3 `exactInput` path ending in the output token.
    /// @param minOut Minimum acceptable output amount.
    /// @param recipient Destination address to receive the output tokens.
    /// @param deadline Swap deadline (unix timestamp).
    /// @param permitOwner If non-zero, the address that authorizes allowance via EIP-2612 permit.
    /// @param permitValue Value approved by permit (must be >= `amountIn`). Ignored if `permitOwner == 0`.
    /// @param permitDeadline Permit signature deadline. Ignored if `permitOwner == 0`.
    /// @param v ECDSA v. Ignored if `permitOwner == 0`.
    /// @param r ECDSA r. Ignored if `permitOwner == 0`.
    /// @param s ECDSA s. Ignored if `permitOwner == 0`.
    /// @return amountOut The amount of output tokens received by `recipient`.
    function zapERC20(
        IERC20 tokenIn,
        uint256 amountIn,
        bytes calldata path,
        uint256 minOut,
        address recipient,
        uint256 deadline,
        address permitOwner,
        uint256 permitValue,
        uint256 permitDeadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        address payer = msg.sender;
        if (permitOwner != address(0)) {
            // Grant allowance to this contract using EIP-2612 permit, then pull tokens from `permitOwner`
            IERC20Permit(address(tokenIn)).permit(permitOwner, address(this), permitValue, permitDeadline, v, r, s);
            payer = permitOwner;
        }

        tokenIn.safeTransferFrom(payer, address(this), amountIn);
        _resetAndApprove(tokenIn, address(swapRouter), amountIn);

        amountOut = swapRouter.exactInput(
            ISwapRouterV3.ExactInputParams({
                path: path,
                recipient: recipient,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: minOut
            })
        );

        emit Zapped(payer, recipient, address(tokenIn), amountIn, amountOut);
    }

    /// @notice Zap native ETH to any output token (determined by `pathFromWETH`) via Uniswap V3.
    /// @dev This function wraps ETH to WETH9, performs the swap, and sends output to `recipient`.
    /// @param pathFromWETH Uniswap V3 `exactInput` path that starts with WETH9 and ends at the output token.
    /// @param minOut Minimum acceptable output amount (slippage protection).
    /// @param recipient Address to receive the output tokens.
    /// @param deadline Unix timestamp after which the transaction should revert.
    /// @return amountOut Amount of output tokens actually received by `recipient`.
    function zapETH(
        bytes calldata pathFromWETH,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external payable nonReentrant returns (uint256 amountOut) {
        uint256 amountIn = msg.value;
        if (amountIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        // Wrap ETH -> WETH9
        WETH9.deposit{ value: amountIn }();
        _resetAndApprove(IERC20(address(WETH9)), address(swapRouter), amountIn);

        amountOut = swapRouter.exactInput(
            ISwapRouterV3.ExactInputParams({
                path: pathFromWETH,
                recipient: recipient,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: minOut
            })
        );

        emit Zapped(msg.sender, recipient, address(0), amountIn, amountOut);
    }

    receive() external payable {}
}

