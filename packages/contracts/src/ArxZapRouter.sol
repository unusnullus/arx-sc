// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IArxTokenSale {
    function buyFor(address buyer, uint256 usdcAmount) external;
    function USDC() external view returns (IERC20);
}

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

interface IWETH9 is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

contract ArxZapRouter is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable USDC; // 6 decimals
    IWETH9 public immutable WETH9;
    ISwapRouter public immutable swapRouter;
    IArxTokenSale public sale;

    event Zapped(address indexed buyer, address indexed tokenIn, uint256 amountIn, uint256 usdcOut);

    error ZeroAddress();
    error ZeroAmount();

    constructor(address _owner, IERC20 _usdc, IWETH9 _weth9, ISwapRouter _router) Ownable(_owner) {
        if (
            address(_usdc) == address(0) || address(_weth9) == address(0)
                || address(_router) == address(0)
        ) {
            revert ZeroAddress();
        }
        USDC = _usdc;
        WETH9 = _weth9;
        swapRouter = _router;
    }

    function setSale(IArxTokenSale _sale) external onlyOwner {
        if (address(_sale) == address(0)) revert ZeroAddress();
        sale = _sale;
        // approve sale to pull USDC when needed is not necessary; we approve from router output to sale below
    }

    function _resetAndApprove(IERC20 token, address spender, uint256 amount) internal {
        token.forceApprove(spender, 0);
        token.forceApprove(spender, amount);
    }

    function zapERC20AndBuy(
        IERC20 tokenIn,
        uint256 amountIn,
        bytes calldata path,
        uint256 minUsdcOut,
        address buyer,
        uint256 deadline
    ) external nonReentrant {
        if (amountIn == 0) revert ZeroAmount();
        // pull tokenIn from sender
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        // approve router
        _resetAndApprove(tokenIn, address(swapRouter), amountIn);
        // swap exact input to USDC
        uint256 usdcOut = swapRouter.exactInput(
            ISwapRouter.ExactInputParams({
                path: path,
                recipient: address(this),
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: minUsdcOut
            })
        );

        // approve sale to pull USDC and buy for buyer
        _resetAndApprove(USDC, address(sale), usdcOut);
        sale.buyFor(buyer, usdcOut);

        emit Zapped(buyer, address(tokenIn), amountIn, usdcOut);
    }

    function zapETHAndBuy(
        bytes calldata pathFromWETH,
        uint256 minUsdcOut,
        address buyer,
        uint256 deadline
    ) external payable nonReentrant {
        uint256 amountIn = msg.value;
        if (amountIn == 0) revert ZeroAmount();
        // wrap ETH
        WETH9.deposit{ value: amountIn }();
        _resetAndApprove(IERC20(address(WETH9)), address(swapRouter), amountIn);

        uint256 usdcOut = swapRouter.exactInput(
            ISwapRouter.ExactInputParams({
                path: pathFromWETH,
                recipient: address(this),
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: minUsdcOut
            })
        );

        _resetAndApprove(USDC, address(sale), usdcOut);
        sale.buyFor(buyer, usdcOut);

        emit Zapped(buyer, address(0), amountIn, usdcOut);
    }

    receive() external payable { }
}
