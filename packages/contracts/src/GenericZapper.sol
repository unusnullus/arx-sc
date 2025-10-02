// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Uniswap V3 swap router interface (exactInput).
interface ISwapRouterV3 {
    struct ExactInputParams {
        bytes path; // token/fee hops encoded per Uniswap spec
        address recipient; // final recipient of the swapped output
        uint256 deadline; // timestamp after which tx reverts
        uint256 amountIn; // exact input amount
        uint256 amountOutMinimum; // slippage protection
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
contract GenericZapper is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    /// @notice WETH9 contract used to wrap/unwrap native ETH for swaps.
    IWETH9 public WETH9;
    /// @notice Uniswap V3 router used for swaps.
    ISwapRouterV3 public swapRouter;

    // No pending balances; output is transferred immediately to recipient post-swap.

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
    error InvalidOutToken();

    /// @notice Initialize the upgradeable zapper.
    /// @param owner_ Owner address with permission to pause/unpause/upgrade.
    /// @param weth9_ Address of WETH9 contract.
    /// @param router_ Address of Uniswap V3 swap router.
    function initialize(address owner_, IWETH9 weth9_, ISwapRouterV3 router_) public initializer {
        if (address(weth9_) == address(0) || address(router_) == address(0)) revert ZeroAddress();
        __Ownable_init(owner_);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        WETH9 = weth9_;
        swapRouter = router_;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }

    /// @notice Return the last token in a Uniswap V3 path (the output token).
    function _lastTokenInPath(bytes calldata path) internal pure returns (address token) {
        bytes memory p = path; // copy to memory for assembly
        assembly {
            let len := mload(p)
            token := shr(96, mload(add(add(p, 32), sub(len, 20))))
        }
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

    /// @notice Single zap entrypoint for both ERC-20 and native ETH with optional EIP-2612 permit.
    /// @dev
    /// - Provide `tokenIn` as address(0) for native ETH; `amountIn` must equal msg.value.
    /// - For ERC-20, if `permitOwner != address(0)`, a permit is executed and tokens are pulled from `permitOwner`.
    /// - Output token must match the last address in the Uniswap V3 `path`.
    /// - Swap output is transferred immediately to `recipient` after routing to this contract.
    /// @param tokenIn Address of ERC-20 to swap from, or address(0) for native ETH.
    /// @param outToken ERC-20 token expected as the final output of `path`.
    /// @param amountIn Exact input amount. For ETH, must equal msg.value.
    /// @param path Uniswap V3 `exactInput` path ending in `outToken`.
    /// @param minOut Minimum acceptable output amount.
    /// @param recipient Destination address that will be able to claim the output.
    /// @param deadline Swap deadline.
    /// @param permitOwner Optional address granting allowance via EIP-2612 permit (ERC-20 only).
    /// @param permitValue Permit value (>= amountIn) when `permitOwner` is set.
    /// @param permitDeadline Permit deadline when `permitOwner` is set.
    /// @param permitV EIP-2612 signature 'v' component for permit (ERC-20 only).
    /// @param permitR EIP-2612 signature 'r' component for permit (ERC-20 only).
    /// @param permitS EIP-2612 signature 's' component for permit (ERC-20 only).
    function zap(
        address tokenIn,
        IERC20 outToken,
        uint256 amountIn,
        bytes calldata path,
        uint256 minOut,
        address recipient,
        uint256 deadline,
        address permitOwner,
        uint256 permitValue,
        uint256 permitDeadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external payable whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (recipient == address(0)) revert ZeroAddress();
        if (address(outToken) != _lastTokenInPath(path)) revert InvalidOutToken();

        if (tokenIn == address(0)) {
            // Native ETH flow
            if (amountIn == 0 || msg.value != amountIn) revert ZeroAmount();
            amountOut = _zapETH(outToken, path, minOut, recipient, deadline, amountIn);
        } else {
            // ERC-20 flow (optional permit)
            IERC20 erc20In = IERC20(tokenIn);
            address payer = msg.sender;
            if (permitOwner != address(0)) {
                IERC20Permit(tokenIn).permit(
                    permitOwner,
                    address(this),
                    permitValue,
                    permitDeadline,
                    permitV,
                    permitR,
                    permitS
                );
                payer = permitOwner;
            }
            if (amountIn == 0) revert ZeroAmount();
            amountOut =
                _zapERC20(erc20In, outToken, amountIn, path, minOut, recipient, deadline, payer);
        }
    }

    function _zapERC20(
        IERC20 tokenIn,
        IERC20 outToken,
        uint256 amountIn,
        bytes calldata path,
        uint256 minOut,
        address recipient,
        uint256 deadline,
        address payer
    ) internal returns (uint256 amountOut) {
        tokenIn.safeTransferFrom(payer, address(this), amountIn);
        _resetAndApprove(tokenIn, address(swapRouter), amountIn);

        amountOut = swapRouter.exactInput(
            ISwapRouterV3.ExactInputParams({
                path: path,
                recipient: address(this),
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: minOut
            })
        );
        // slither-disable-next-line reentrancy-no-eth,reentrancy-benign
        outToken.safeTransfer(recipient, amountOut);
        emit Zapped(payer, recipient, address(tokenIn), amountIn, amountOut);
    }

    function _zapETH(
        IERC20 outToken,
        bytes calldata pathFromWETH,
        uint256 minOut,
        address recipient,
        uint256 deadline,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        WETH9.deposit{ value: amountIn }();
        _resetAndApprove(IERC20(address(WETH9)), address(swapRouter), amountIn);

        amountOut = swapRouter.exactInput(
            ISwapRouterV3.ExactInputParams({
                path: pathFromWETH,
                recipient: address(this),
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: minOut
            })
        );
        // slither-disable-next-line reentrancy-no-eth,reentrancy-benign
        outToken.safeTransfer(recipient, amountOut);
        emit Zapped(msg.sender, recipient, address(0), amountIn, amountOut);
    }

    // No claim function; outputs are sent immediately.

    receive() external payable { }
}
