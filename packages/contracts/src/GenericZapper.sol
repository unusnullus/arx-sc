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
/// @notice Generic zapper for swapping ERC-20 or native ETH to any desired output token
///         via Uniswap V3, sending the output directly to the provided recipient.
/// @dev This contract is protocol-agnostic and does not assume a specific post-swap action.
///      It simply routes swaps and sends the output to a recipient. For integrations
///      (e.g., token sales, deposit hooks), call the integration directly after receiving
///      tokens at the recipient.
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

    /// @notice Ensure allowance >= amount; reset to 0 first if needed (OZ v5 forceApprove).
    function _resetAndApprove(IERC20 token, address spender, uint256 amount) internal {
        uint256 current = token.allowance(address(this), spender);
        if (current < amount) {
            if (current > 0) {
                token.forceApprove(spender, 0);
            }
            token.forceApprove(spender, amount);
        }
    }

    /// @notice Zap an ERC-20 `tokenIn` to any output token (determined by `path`) via Uniswap V3.
    /// @dev The output is sent directly to `recipient` by setting the router recipient.
    /// @param tokenIn ERC-20 token to swap from.
    /// @param amountIn Exact amount of `tokenIn` to swap.
    /// @param path Uniswap V3 `exactInput` path ending at the desired output token.
    /// @param minOut Minimum acceptable output amount (slippage protection).
    /// @param recipient Address to receive the final output tokens.
    /// @param deadline Unix timestamp after which the transaction should revert.
    /// @return amountOut Amount of output tokens actually received by `recipient`.
    function zapERC20(
        IERC20 tokenIn,
        uint256 amountIn,
        bytes calldata path,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        // Pull tokenIn from the caller and approve the router
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        _resetAndApprove(tokenIn, address(swapRouter), amountIn);

        amountOut = swapRouter.exactInput(
            ISwapRouterV3.ExactInputParams({
                path: path,
                recipient: recipient, // send output directly to recipient
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: minOut
            })
        );

        emit Zapped(msg.sender, recipient, address(tokenIn), amountIn, amountOut);
    }

    /// @notice Zap ERC-20 with EIP-2612 permit to avoid a prior on-chain approval.
    /// @param owner Address granting allowance via permit; tokens are pulled from this address.
    /// @param permitValue Allowance value to set via permit (>= amountIn).
    /// @param permitDeadline Deadline for the permit signature.
    /// @param v ECDSA v
    /// @param r ECDSA r
    /// @param s ECDSA s
    function zapERC20WithPermit(
        IERC20 tokenIn,
        uint256 amountIn,
        bytes calldata path,
        uint256 minOut,
        address recipient,
        uint256 deadline,
        address owner,
        uint256 permitValue,
        uint256 permitDeadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        // Grant allowance to this contract using permit, then pull tokens from owner
        IERC20Permit(address(tokenIn)).permit(owner, address(this), permitValue, permitDeadline, v, r, s);
        tokenIn.safeTransferFrom(owner, address(this), amountIn);
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

        emit Zapped(owner, recipient, address(tokenIn), amountIn, amountOut);
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

