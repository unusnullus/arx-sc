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
/// @notice Single-call "zap and buy" for ARX: swap ERC-20 or native ETH into USDC via Uniswap V3,
///         then purchase ARX for the provided buyer using the sale contract.
/// @dev
/// - Safe approvals using allowance check + forceApprove for non-standard tokens.
/// - Route swap output to this contract first, then approve and call sale.buyFor.
/// - Path validation ensures the last token in the Uniswap V3 path is USDC to avoid misroutes.
/// - UUPS upgradeable + Pausable for safe operations and flexibility.
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
    error InvalidUSDCPath();

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

    /// @notice Return the last token in a Uniswap V3 path (the output token).
    function _lastTokenInPath(bytes calldata path) internal pure returns (address token) {
        bytes memory p = path;
        assembly {
            let len := mload(p)
            token := shr(96, mload(add(add(p, 32), sub(len, 20))))
        }
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

    /// @notice One-function API: swap to USDC via Uniswap V3 and buy ARX for `buyer`.
    /// @dev
    /// - If `tokenIn == address(0)`, `amountIn` must equal `msg.value`, and ETH will be wrapped to WETH9.
    /// - For ERC-20, optional EIP-2612 permit is supported via `permitOwner/permit*`.
    /// - The provided `path` MUST end with USDC or this reverts.
    /// @param tokenIn ERC-20 token address to swap from, or address(0) for native ETH.
    /// @param amountIn Exact input amount. For ETH, must equal msg.value.
    /// @param path Uniswap V3 encoded path of hops that MUST end in USDC.
    /// @param minUsdcOut Minimum USDC output after the swap.
    /// @param buyer Address to receive the purchased ARX.
    /// @param deadline Unix timestamp after which the swap should revert.
    /// @param permitOwner If non-zero, the address granting allowance via EIP-2612 permit.
    /// @param permitValue Permit value (>= amountIn) when `permitOwner` is set.
    /// @param permitDeadline Permit deadline when `permitOwner` is set.
    /// @param permitV EIP-2612 signature v.
    /// @param permitR EIP-2612 signature r.
    /// @param permitS EIP-2612 signature s.
    function zapAndBuy(
        address tokenIn,
        uint256 amountIn,
        bytes calldata path,
        uint256 minUsdcOut,
        address buyer,
        uint256 deadline,
        address permitOwner,
        uint256 permitValue,
        uint256 permitDeadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external payable whenNotPaused nonReentrant {
        if (amountIn == 0) revert ZeroAmount();
        if (_lastTokenInPath(path) != address(USDC)) revert InvalidUSDCPath();

        uint256 usdcOut;
        if (tokenIn == address(0)) {
            // Native ETH -> WETH9 -> ... -> USDC
            if (msg.value != amountIn) revert ZeroAmount();
            WETH9.deposit{ value: amountIn }();
            _resetAndApprove(IERC20(address(WETH9)), address(swapRouter), amountIn);
            usdcOut = swapRouter.exactInput(
                ISwapRouter.ExactInputParams({
                    path: path,
                    recipient: address(this),
                    deadline: deadline,
                    amountIn: amountIn,
                    amountOutMinimum: minUsdcOut
                })
            );
        } else {
            IERC20 erc20In = IERC20(tokenIn);
            address payer = msg.sender;
            if (permitOwner != address(0)) {
                IERC20Permit(tokenIn).permit(permitOwner, address(this), permitValue, permitDeadline, permitV, permitR, permitS);
                payer = permitOwner;
            }
            erc20In.safeTransferFrom(payer, address(this), amountIn);
            _resetAndApprove(erc20In, address(swapRouter), amountIn);
            usdcOut = swapRouter.exactInput(
                ISwapRouter.ExactInputParams({
                    path: path,
                    recipient: address(this),
                    deadline: deadline,
                    amountIn: amountIn,
                    amountOutMinimum: minUsdcOut
                })
            );
        }

        _resetAndApprove(USDC, address(sale), usdcOut);
        sale.buyFor(buyer, usdcOut);
        emit Zapped(buyer, tokenIn, amountIn, usdcOut);
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
        zapAndBuy(address(tokenIn), amountIn, path, minUsdcOut, buyer, deadline, address(0), 0, 0, 0, bytes32(0), bytes32(0));
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
        zapAndBuy(address(tokenIn), amountIn, path, minUsdcOut, buyer, deadline, owner, permitValue, permitDeadline, v, r, s);
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
        zapAndBuy(address(0), msg.value, pathFromWETH, minUsdcOut, buyer, deadline, address(0), 0, 0, 0, bytes32(0), bytes32(0));
    }

    receive() external payable {}

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
// Removed in minimal setup (zap router not used)
