// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {
    PausableUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Minimal interface to interact with the ARX token sale contract
/// @dev Provides the buyFor function to purchase ARX tokens and access to USDC token reference
interface IArxTokenSale {
    /// @notice Purchases ARX tokens for a specified buyer using USDC
    /// @param buyer The address that will receive the purchased ARX tokens
    /// @param usdcAmount The amount of USDC to use for the purchase (6 decimals)
    function buyFor(address buyer, uint256 usdcAmount) external;

    /// @notice Returns the USDC token contract used by the sale
    /// @return The IERC20 interface of the USDC token
    function USDC() external view returns (IERC20);
}

/// @notice Uniswap V3 swap router interface for exact input swaps
/// @dev Used to execute token swaps via Uniswap V3 with exact input amounts
interface ISwapRouter {
    /// @notice Parameters for exact input swap operations
    struct ExactInputParams {
        bytes path; // Encoded token/fee path for the swap route
        address recipient; // Address that receives the swap output
        uint256 deadline; // Unix timestamp after which the swap should revert
        uint256 amountIn; // Exact amount of input tokens to swap
        uint256 amountOutMinimum; // Minimum acceptable output amount (slippage protection)
    }

    /// @notice Executes an exact input swap
    /// @param params The swap parameters including path, amounts, and recipient
    /// @return amountOut The actual amount of output tokens received
    function exactInput(
        ExactInputParams calldata params
    ) external payable returns (uint256 amountOut);
}

/// @notice Minimal WETH9 interface for wrapping and unwrapping native ETH
/// @dev Used to convert native ETH to WETH for Uniswap swaps
interface IWETH9 is IERC20 {
    /// @notice Wraps native ETH into WETH tokens
    function deposit() external payable;

    /// @notice Unwraps WETH tokens back to native ETH
    /// @param amount The amount of WETH to unwrap
    function withdraw(uint256 amount) external;
}

/// @notice Minimal ERC20Permit interface for EIP-2612 permit functionality
/// @dev Enables gasless token approvals via signature-based permits
interface IERC20Permit {
    /// @notice Executes an EIP-2612 permit to grant token spending allowance
    /// @param owner The token owner granting the approval
    /// @param spender The address receiving the approval
    /// @param value The amount of tokens to approve
    /// @param deadline The timestamp after which the permit expires
    /// @param v The recovery byte of the signature
    /// @param r The r component of the signature
    /// @param s The s component of the signature
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

/**
 * @title ArxZapRouter
 * @notice A single-call "zap and buy" router for ARX tokens that enables users to swap various
 *         ERC-20 tokens or native ETH into USDC via Uniswap V3, then automatically purchase ARX
 *         tokens through the sale contract in a single transaction.
 * @dev This contract provides a seamless experience for users to acquire ARX tokens using any
 *      supported input token. It handles token swaps, approvals, and ARX purchases atomically.
 *
 *      Key features:
 *      - Supports both ERC-20 tokens and native ETH as input
 *      - Optional EIP-2612 permit support for gasless approvals
 *      - Safe approval patterns using allowance checks and forceApprove for non-standard tokens
 *      - Path validation ensures swap routes end with USDC to prevent misrouting
 *      - UUPS upgradeable architecture for future enhancements
 *      - Pausable for emergency stops
 *      - Reentrancy protection on all external functions
 *
 *      Security considerations:
 *      - Swap output is routed to this contract first, then transferred to sale contract
 *      - Approvals are reset to zero after use to minimize attack surface
 *      - Path validation prevents accidental swaps to wrong tokens
 *      - All external calls follow checks-effects-interactions pattern
 */
contract ArxZapRouter is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    /// @notice USDC token contract used by the sale (6 decimals)
    /// @dev This is the target token that all swaps must output before purchasing ARX
    IERC20 public USDC;

    /// @notice WETH9 contract for wrapping/unwrapping native ETH
    /// @dev Required for handling native ETH deposits that need to be swapped
    IWETH9 public WETH9;

    /// @notice Uniswap V3 swap router for executing token swaps
    /// @dev Used to convert input tokens to USDC via Uniswap V3 pools
    ISwapRouter public swapRouter;

    /// @notice ARX token sale contract for purchasing ARX tokens
    /// @dev Receives USDC and mints/distributes ARX tokens to buyers
    IArxTokenSale public sale;

    /**
     * @notice Emitted when a zap and buy operation completes successfully
     * @param buyer The address that received the purchased ARX tokens
     * @param tokenIn The input token address (address(0) for native ETH)
     * @param amountIn The amount of input tokens used in the swap
     * @param usdcOut The amount of USDC received from the swap and used to purchase ARX
     */
    event Zapped(
        address indexed buyer,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 usdcOut
    );

    /// @notice Reverts when a zero address is provided where a valid address is required
    error ZeroAddress();

    /// @notice Reverts when a zero amount is provided where a positive amount is required
    error ZeroAmount();

    /// @notice Reverts when the Uniswap path does not end with USDC token
    /// @dev This ensures swaps always result in USDC, which is required for ARX purchase
    error InvalidUSDCPath();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the ArxZapRouter contract with all required dependencies
     * @dev This function sets up the complete zapper infrastructure including token contracts,
     *      DEX integration, and access controls. It must be called once during contract deployment
     *      via the proxy pattern.
     *
     * @param _owner The address that will own the contract and have permission to pause/unpause/upgrade
     * @param _usdc The USDC token contract address (6 decimals expected)
     * @param _weth9 The WETH9 contract address for ETH wrapping/unwrapping
     * @param _router The Uniswap V3 swap router address for executing token swaps
     */
    function initialize(
        address _owner,
        IERC20 _usdc,
        IWETH9 _weth9,
        ISwapRouter _router
    ) public initializer {
        if (
            address(_usdc) == address(0) ||
            address(_weth9) == address(0) ||
            address(_router) == address(0)
        ) {
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

    /**
     * @notice Pauses the contract, preventing all zap and buy operations
     * @dev This function can only be called by the contract owner. When paused, all external
     *      functions that modify state will revert, providing an emergency stop mechanism.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the contract, allowing zap and buy operations to resume
     * @dev This function can only be called by the contract owner. It restores normal
     *      contract functionality after a pause.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Sets the ARX token sale contract used for purchasing ARX tokens
     * @dev This function allows the owner to update the sale contract address, which is useful
     *      for upgrades or changing sale parameters. The sale contract must implement the
     *      IArxTokenSale interface.
     *
     * @param _sale The address of the ARX token sale contract
     */
    function setSale(address _sale) external onlyOwner {
        if (_sale == address(0)) revert ZeroAddress();
        sale = IArxTokenSale(_sale);
    }

    /**
     * @notice Extracts the last token address from a Uniswap V3 encoded path
     * @dev Uniswap V3 paths encode token addresses and fee tiers in a specific byte format.
     *      This function uses assembly to efficiently extract the final token address (output token)
     *      from the path. The path format is: token0 (20 bytes) | fee (3 bytes) | token1 (20 bytes) | ...
     *
     * @param path The Uniswap V3 encoded swap path
     * @return token The address of the last token in the path (the output token)
     */
    function _lastTokenInPath(
        bytes calldata path
    ) internal pure returns (address token) {
        bytes memory p = path; // Copy to memory for assembly operations
        assembly {
            let len := mload(p) // Get path length
            // Extract last 20 bytes (token address) from the path
            token := shr(96, mload(add(add(p, 32), sub(len, 20))))
        }
    }

    /**
     * @notice Ensures the contract has sufficient allowance for a spender, resetting if needed
     * @dev This function implements a safe approval pattern that handles non-standard ERC-20 tokens.
     *      It checks current allowance and only updates if insufficient. For tokens that don't allow
     *      changing non-zero allowances, it resets to zero first using forceApprove.
     *
     *      This pattern minimizes gas usage by only updating when necessary and handles edge cases
     *      for tokens with unusual approval behavior.
     *
     * @param token The ERC-20 token contract to approve
     * @param spender The address that will be approved to spend tokens
     * @param amount The minimum amount of tokens that should be approved
     */
    function _resetAndApprove(
        IERC20 token,
        address spender,
        uint256 amount
    ) internal {
        uint256 current = token.allowance(address(this), spender);
        if (current < amount) {
            // Reset to zero first for tokens that don't allow changing non-zero allowances
            if (current > 0) {
                token.forceApprove(spender, 0);
            }
            token.forceApprove(spender, amount);
        }
    }

    /**
     * @notice Executes an ERC20 permit for gasless token approvals
     * @dev This function enables users to approve token spending without a separate transaction
     *      by using EIP-2612 permit functionality. It executes the permit directly as in the
     *      original implementation.
     *
     * @param token The ERC20Permit token contract
     * @param owner The token owner granting the approval
     * @param spender The address receiving the approval (typically this contract)
     * @param permitValue The permit value
     * @param permitDeadline The permit deadline timestamp
     * @param permitV The EIP-2612 signature v component
     * @param permitR The EIP-2612 signature r component
     * @param permitS The EIP-2612 signature s component
     */
    function _execPermit(
        IERC20 token,
        address owner,
        address spender,
        uint256 permitValue,
        uint256 permitDeadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) internal {
        IERC20Permit(address(token)).permit(
            owner,
            spender,
            permitValue,
            permitDeadline,
            permitV,
            permitR,
            permitS
        );
    }

    /**
     * @notice Swaps native ETH to USDC via Uniswap V3
     * @dev This function handles the complete ETH-to-USDC conversion process:
     *      1. Wraps native ETH to WETH9
     *      2. Approves Uniswap router to spend WETH9
     *      3. Executes swap via Uniswap V3
     *      4. Returns the USDC amount received
     *
     * @param pathFromWETH The Uniswap V3 encoded swap path starting from WETH9 and ending in USDC
     * @param minUsdcOut The minimum acceptable USDC output amount (slippage protection, 6 decimals)
     * @param deadline The Unix timestamp after which the swap should revert
     * @param amountIn The amount of native ETH to swap (must equal msg.value)
     * @return usdcOut The amount of USDC received from the swap (6 decimals)
     */
    function _zapETH(
        bytes calldata pathFromWETH,
        uint256 minUsdcOut,
        uint256 deadline,
        uint256 amountIn
    ) internal returns (uint256 usdcOut) {
        // Wrap native ETH to WETH9
        WETH9.deposit{value: amountIn}();

        // Approve router to spend WETH9
        _resetAndApprove(IERC20(address(WETH9)), address(swapRouter), amountIn);

        // Execute swap: WETH9 -> ... -> USDC
        usdcOut = swapRouter.exactInput(
            ISwapRouter.ExactInputParams({
                path: pathFromWETH,
                recipient: address(this), // Route output to this contract first
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: minUsdcOut
            })
        );
    }

    /**
     * @notice Swaps ERC-20 tokens to USDC via Uniswap V3
     * @dev This function handles the complete ERC-20-to-USDC conversion process:
     *      1. Optionally executes EIP-2612 permit if provided
     *      2. Transfers tokens from payer to this contract
     *      3. Approves Uniswap router to spend input token
     *      4. Executes swap via Uniswap V3
     *      5. Returns the USDC amount received
     *
     * @param tokenIn The ERC-20 token to swap from
     * @param amountIn The amount of input tokens to swap (in token's native decimals)
     * @param path The Uniswap V3 encoded swap path that MUST end with USDC token address
     * @param minUsdcOut The minimum acceptable USDC output amount (slippage protection, 6 decimals)
     * @param deadline The Unix timestamp after which the swap should revert
     * @param payer The address that will provide the input tokens
     * @param permitOwner Optional address granting allowance via EIP-2612 permit
     * @param permitValue The permit value (must be >= amountIn) when permitOwner is set
     * @param permitDeadline The permit deadline timestamp when permitOwner is set
     * @param permitV The EIP-2612 signature v component (permit only)
     * @param permitR The EIP-2612 signature r component (permit only)
     * @param permitS The EIP-2612 signature s component (permit only)
     * @return usdcOut The amount of USDC received from the swap (6 decimals)
     */
    function _zapERC20(
        IERC20 tokenIn,
        uint256 amountIn,
        bytes calldata path,
        uint256 minUsdcOut,
        uint256 deadline,
        address payer,
        address permitOwner,
        uint256 permitValue,
        uint256 permitDeadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) internal returns (uint256 usdcOut) {
        // Execute EIP-2612 permit if provided (gasless approval)
        // Original logic: permit is called directly without allowance check
        if (permitOwner != address(0)) {
            _execPermit(
                tokenIn,
                permitOwner,
                address(this),
                permitValue,
                permitDeadline,
                permitV,
                permitR,
                permitS
            );
            payer = permitOwner; // Tokens will be pulled from permit owner
        }

        // Transfer tokens from payer to this contract
        tokenIn.safeTransferFrom(payer, address(this), amountIn);

        // Approve router to spend input token
        _resetAndApprove(tokenIn, address(swapRouter), amountIn);

        // Execute swap: tokenIn -> ... -> USDC
        usdcOut = swapRouter.exactInput(
            ISwapRouter.ExactInputParams({
                path: path,
                recipient: address(this), // Route output to this contract first
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: minUsdcOut
            })
        );
    }

    /**
     * @notice Processes direct USDC payment and purchases ARX tokens
     * @dev This function handles the direct USDC payment flow without any swaps.
     *      It transfers USDC from the payer to this contract, then purchases ARX.
     *
     * @param payer The address that will provide the USDC tokens
     * @param amount The amount of USDC to use for the purchase (6 decimals)
     * @param buyer The address that will receive the purchased ARX tokens
     */
    function _processUSDC(
        address payer,
        uint256 amount,
        address buyer
    ) internal {
        // Transfer USDC from payer to this contract
        USDC.safeTransferFrom(payer, address(this), amount);

        // Process final step: approve sale and purchase ARX
        _processZapAndBuy(buyer, amount);
    }

    /**
     * @notice Processes the final step: approves sale contract and purchases ARX tokens
     * @dev This function handles the USDC approval and ARX purchase after a successful swap.
     *      It follows the checks-effects-interactions pattern by clearing the allowance
     *      immediately after the external call.
     *
     * @param buyer The address that will receive the purchased ARX tokens
     * @param usdcAmount The amount of USDC to use for the purchase (6 decimals)
     */
    function _processZapAndBuy(address buyer, uint256 usdcAmount) internal {
        // Approve sale contract to spend USDC
        _resetAndApprove(USDC, address(sale), usdcAmount);

        // External call to sale contract to purchase ARX tokens
        // No state changes occur after this call, and allowance is cleared immediately
        // slither-disable-next-line reentrancy-no-eth,reentrancy-benign
        sale.buyFor(buyer, usdcAmount);

        // Clear allowance to minimize attack surface
        USDC.forceApprove(address(sale), 0);
    }

    /**
     * @notice Internal function that orchestrates the complete zap-and-buy flow
     * @dev This is the core function that handles all token types (ETH, USDC, ERC-20)
     *      and optional permit support. Used by public zap functions.
     *
     * @param tokenIn The ERC-20 token address to swap from, address(USDC) for direct USDC, or address(0) for native ETH
     * @param amountIn The exact amount of input tokens to swap (in token's native decimals)
     * @param path The Uniswap V3 encoded swap path that MUST end with USDC token address (ignored for direct USDC)
     * @param minUsdcOut The minimum acceptable USDC output amount (slippage protection, 6 decimals, ignored for direct USDC)
     * @param buyer The address that will receive the purchased ARX tokens
     * @param deadline The Unix timestamp after which the swap should revert (prevents stale txs, ignored for direct USDC)
     * @param permitOwner Optional address granting allowance via EIP-2612 permit (ERC-20 only, including USDC)
     * @param permitValue The permit value (must be >= amountIn) when permitOwner is set
     * @param permitDeadline The permit deadline timestamp when permitOwner is set
     * @param permitV The EIP-2612 signature v component (permit only)
     * @param permitR The EIP-2612 signature r component (permit only)
     * @param permitS The EIP-2612 signature s component (permit only)
     */
    function _zapAndBuyInternal(
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
    ) internal {
        // Validate input parameters
        if (amountIn == 0) revert ZeroAmount();

        uint256 usdcOut;

        if (tokenIn == address(0)) {
            // Native ETH flow: wrap to WETH9, then swap to USDC
            // Original logic: path validation happens before processing
            if (msg.value != amountIn) revert ZeroAmount();
            if (_lastTokenInPath(path) != address(USDC)) {
                revert InvalidUSDCPath();
            }
            usdcOut = _zapETH(path, minUsdcOut, deadline, amountIn);
            // Process final step: approve sale and purchase ARX
            _processZapAndBuy(buyer, usdcOut);
        } else if (tokenIn == address(USDC)) {
            // Direct USDC flow: no swap needed, use USDC directly
            // Path validation not required for direct USDC
            address payer = msg.sender;

            // Execute EIP-2612 permit if provided (gasless approval)
            // Original logic: permit is called directly without allowance check
            if (permitOwner != address(0)) {
                _execPermit(
                    USDC,
                    permitOwner,
                    address(this),
                    permitValue,
                    permitDeadline,
                    permitV,
                    permitR,
                    permitS
                );
                payer = permitOwner; // Tokens will be pulled from permit owner
            }

            // Transfer USDC from payer to this contract and purchase ARX
            _processUSDC(payer, amountIn, buyer);
            usdcOut = amountIn;
        } else {
            // ERC-20 token flow: transfer, optionally use permit, then swap to USDC
            // Original logic: path validation happens before processing
            if (_lastTokenInPath(path) != address(USDC)) {
                revert InvalidUSDCPath();
            }
            IERC20 erc20In = IERC20(tokenIn);
            usdcOut = _zapERC20(
                erc20In,
                amountIn,
                path,
                minUsdcOut,
                deadline,
                msg.sender,
                permitOwner,
                permitValue,
                permitDeadline,
                permitV,
                permitR,
                permitS
            );
            // Process final step: approve sale and purchase ARX
            _processZapAndBuy(buyer, usdcOut);
        }

        // Emit event
        emit Zapped(buyer, tokenIn, amountIn, usdcOut);
    }

    /**
     * @notice Universal zap function to swap any token (ETH, USDC, or ERC-20) to USDC and buy ARX
     * @dev This is the main entry point for zapping tokens and purchasing ARX. It automatically
     *      handles different input types:
     *      - Native ETH (address(0)): Wraps to WETH9 and swaps to USDC
     *      - USDC (address(USDC)): Direct purchase without swap
     *      - Other ERC-20 tokens: Swaps to USDC via Uniswap V3
     *
     *      The caller must have pre-approved this contract to spend `tokenIn` (for ERC-20 tokens).
     *
     * @param tokenIn The token address: address(0) for ETH, address(USDC) for direct USDC, or any ERC-20 token
     * @param amountIn The amount of input tokens (in token's native decimals). For ETH, must equal msg.value
     * @param path The Uniswap V3 swap path (required for ETH and ERC-20, ignored for USDC)
     * @param minUsdcOut Minimum USDC output (slippage protection, required for ETH and ERC-20, ignored for USDC)
     * @param buyer The address that will receive the purchased ARX tokens
     * @param deadline The swap deadline timestamp (required for ETH and ERC-20, ignored for USDC)
     */
    function zapAndBuy(
        address tokenIn,
        uint256 amountIn,
        bytes calldata path,
        uint256 minUsdcOut,
        address buyer,
        uint256 deadline
    ) external payable whenNotPaused nonReentrant {
        _zapAndBuyInternal(
            tokenIn,
            amountIn,
            path,
            minUsdcOut,
            buyer,
            deadline,
            address(0),
            0,
            0,
            0,
            bytes32(0),
            bytes32(0)
        );
    }

    /**
     * @notice Universal zap function with EIP-2612 permit support to swap any token and buy ARX
     * @dev This function provides gasless approvals via EIP-2612 permit. It automatically
     *      handles different input types:
     *      - Native ETH (address(0)): Wraps to WETH9 and swaps to USDC (permit is ignored)
     *      - USDC (address(USDC)): Direct purchase with permit (path, minUsdcOut, deadline are ignored)
     *      - Other ERC-20 tokens: Swaps to USDC via Uniswap V3 with permit
     *
     *      The permit signature must be valid and signed by `owner`, granting this contract
     *      permission to spend `permitValue` amount of `tokenIn`.
     *
     * @param tokenIn The token address: address(0) for ETH, address(USDC) for direct USDC, or any ERC-20 token
     * @param amountIn The amount of input tokens (in token's native decimals). For ETH, must equal msg.value
     * @param path The Uniswap V3 swap path (required for ETH and ERC-20, ignored for USDC)
     * @param minUsdcOut Minimum USDC output (slippage protection, required for ETH and ERC-20, ignored for USDC)
     * @param buyer The address that will receive the purchased ARX tokens
     * @param deadline The swap deadline timestamp (required for ETH and ERC-20, ignored for USDC)
     * @param owner The address that owns the tokens and is granting the permit (ignored for ETH)
     * @param permitValue The permit value (must be >= amountIn)
     * @param permitDeadline The permit deadline timestamp
     * @param v The EIP-2612 signature v component
     * @param r The EIP-2612 signature r component
     * @param s The EIP-2612 signature s component
     */
    function zapAndBuyWithPermit(
        address tokenIn,
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
    ) external payable whenNotPaused nonReentrant {
        _zapAndBuyInternal(
            tokenIn,
            amountIn,
            path,
            minUsdcOut,
            buyer,
            deadline,
            owner,
            permitValue,
            permitDeadline,
            v,
            r,
            s
        );
    }

    /**
     * @notice Receives native ETH sent directly to the contract
     * @dev This function allows the contract to accept ETH transfers. However, users should
     *      use `zapAndBuy` with tokenIn = address(0) for proper functionality.
     *      ETH sent directly via this function will remain in the contract.
     */
    receive() external payable {}

    /**
     * @notice Authorizes contract upgrades (UUPS pattern)
     * @dev This function controls who can upgrade the contract implementation. Only the owner
     *      can authorize upgrades, providing a security mechanism for contract updates.
     *
     * @param newImplementation The address of the new implementation contract (unused but required by UUPS)
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {
        // Implementation address is validated by UUPSUpgradeable
        // Only owner can authorize upgrades
    }
}
