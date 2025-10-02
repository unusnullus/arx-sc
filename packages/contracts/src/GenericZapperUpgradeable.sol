// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ISwapRouterV3Like2 {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

interface IWETH9Like2 is IERC20 { function deposit() external payable; }

interface IERC20PermitLike2 {
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

/// @title GenericZapper (Upgradeable & Pausable)
/// @notice Protocol-agnostic zapper to swap ERC-20 or native ETH into any output token via Uniswap V3.
/// @dev UUPS upgradeable + Pausable to safely halt operations if needed.
contract GenericZapperUpgradeable is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    IWETH9Like2 public WETH9;
    ISwapRouterV3Like2 public swapRouter;

    event Zapped(address indexed sender, address indexed recipient, address indexed tokenIn, uint256 amountIn, uint256 amountOut);

    error ZeroAddress();
    error ZeroAmount();
    error InvalidOutToken();

    function initialize(address owner_, IWETH9Like2 weth9_, ISwapRouterV3Like2 router_) public initializer {
        if (address(weth9_) == address(0) || address(router_) == address(0)) revert ZeroAddress();
        __Ownable_init(owner_);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        WETH9 = weth9_;
        swapRouter = router_;
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _resetAndApprove(IERC20 token, address spender, uint256 amount) internal {
        uint256 current = token.allowance(address(this), spender);
        if (current < amount) {
            if (current > 0) { token.forceApprove(spender, 0); }
            token.forceApprove(spender, amount);
        }
    }

    function _lastTokenInPath(bytes calldata path) internal pure returns (address token) {
        bytes memory p = path;
        assembly {
            let len := mload(p)
            token := shr(96, mload(add(add(p, 32), sub(len, 20))))
        }
    }

    /// @notice Zap ERC-20 into an output token via Uniswap V3 with optional EIP-2612 permit.
    function zapERC20(
        IERC20 tokenIn,
        IERC20 outToken,
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
    ) external whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        address payer = msg.sender;
        if (permitOwner != address(0)) {
            IERC20PermitLike2(address(tokenIn)).permit(permitOwner, address(this), permitValue, permitDeadline, v, r, s);
            payer = permitOwner;
        }

        tokenIn.safeTransferFrom(payer, address(this), amountIn);
        _resetAndApprove(tokenIn, address(swapRouter), amountIn);

        if (address(outToken) != _lastTokenInPath(path)) revert InvalidOutToken();

        amountOut = swapRouter.exactInput(ISwapRouterV3Like2.ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: deadline,
            amountIn: amountIn,
            amountOutMinimum: minOut
        }));

        outToken.safeTransfer(recipient, amountOut);
        emit Zapped(payer, recipient, address(tokenIn), amountIn, amountOut);
    }

    /// @notice Zap native ETH into an output token via Uniswap V3.
    function zapETH(
        IERC20 outToken,
        bytes calldata pathFromWETH,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external payable whenNotPaused nonReentrant returns (uint256 amountOut) {
        uint256 amountIn = msg.value; if (amountIn == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        WETH9.deposit{ value: amountIn }();
        _resetAndApprove(IERC20(address(WETH9)), address(swapRouter), amountIn);

        amountOut = swapRouter.exactInput(ISwapRouterV3Like2.ExactInputParams({
            path: pathFromWETH,
            recipient: address(this),
            deadline: deadline,
            amountIn: amountIn,
            amountOutMinimum: minOut
        }));

        outToken.safeTransfer(recipient, amountOut);
        emit Zapped(msg.sender, recipient, address(0), amountIn, amountOut);
    }
}


