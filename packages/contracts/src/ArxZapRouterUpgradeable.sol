// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ISwapRouterV3Like {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

interface IWETH9Like is IERC20 { function deposit() external payable; }
interface IArxSaleLike { function buyFor(address buyer, uint256 usdcAmount) external; function USDC() external view returns (IERC20); }
interface IERC20PermitLike {
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

/// @title ArxZapRouter (Upgradeable)
contract ArxZapRouterUpgradeable is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 public USDC;
    IWETH9Like public WETH9;
    ISwapRouterV3Like public swapRouter;
    IArxSaleLike public sale;

    event Zapped(address indexed buyer, address indexed tokenIn, uint256 amountIn, uint256 usdcOut);

    error ZeroAddress();
    error ZeroAmount();

    function initialize(address _owner, IERC20 _usdc, IWETH9Like _weth9, ISwapRouterV3Like _router, IArxSaleLike _sale) public initializer {
        if (address(_usdc) == address(0) || address(_weth9) == address(0) || address(_router) == address(0) || address(_sale) == address(0)) revert ZeroAddress();
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        USDC = _usdc;
        WETH9 = _weth9;
        swapRouter = _router;
        sale = _sale;
    }

    function setSale(IArxSaleLike _sale) external onlyOwner { if (address(_sale) == address(0)) revert ZeroAddress(); sale = _sale; }

    function _resetAndApprove(IERC20 token, address spender, uint256 amount) internal {
        uint256 current = token.allowance(address(this), spender);
        if (current < amount) {
            if (current > 0) { token.forceApprove(spender, 0); }
            token.forceApprove(spender, amount);
        }
    }

    function zapERC20AndBuy(IERC20 tokenIn, uint256 amountIn, bytes calldata path, uint256 minUsdcOut, address buyer, uint256 deadline) external nonReentrant {
        if (amountIn == 0) revert ZeroAmount();
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        _resetAndApprove(tokenIn, address(swapRouter), amountIn);
        uint256 usdcOut = swapRouter.exactInput(ISwapRouterV3Like.ExactInputParams({ path: path, recipient: address(this), deadline: deadline, amountIn: amountIn, amountOutMinimum: minUsdcOut }));
        _resetAndApprove(USDC, address(sale), usdcOut);
        sale.buyFor(buyer, usdcOut);
        emit Zapped(buyer, address(tokenIn), amountIn, usdcOut);
    }

    function zapETHAndBuy(bytes calldata pathFromWETH, uint256 minUsdcOut, address buyer, uint256 deadline) external payable nonReentrant {
        uint256 amountIn = msg.value; if (amountIn == 0) revert ZeroAmount();
        WETH9.deposit{ value: amountIn }();
        _resetAndApprove(IERC20(address(WETH9)), address(swapRouter), amountIn);
        uint256 usdcOut = swapRouter.exactInput(ISwapRouterV3Like.ExactInputParams({ path: pathFromWETH, recipient: address(this), deadline: deadline, amountIn: amountIn, amountOutMinimum: minUsdcOut }));
        _resetAndApprove(USDC, address(sale), usdcOut);
        sale.buyFor(buyer, usdcOut);
        emit Zapped(buyer, address(0), amountIn, usdcOut);
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
    ) external nonReentrant {
        if (amountIn == 0) revert ZeroAmount();
        IERC20PermitLike(address(tokenIn)).permit(owner, address(this), permitValue, permitDeadline, v, r, s);
        tokenIn.safeTransferFrom(owner, address(this), amountIn);
        _resetAndApprove(tokenIn, address(swapRouter), amountIn);
        uint256 usdcOut = swapRouter.exactInput(ISwapRouterV3Like.ExactInputParams({ path: path, recipient: address(this), deadline: deadline, amountIn: amountIn, amountOutMinimum: minUsdcOut }));
        _resetAndApprove(USDC, address(sale), usdcOut);
        sale.buyFor(buyer, usdcOut);
        emit Zapped(buyer, address(tokenIn), amountIn, usdcOut);
    }

    receive() external payable {}

    function _authorizeUpgrade(address) internal override onlyOwner {}
}


