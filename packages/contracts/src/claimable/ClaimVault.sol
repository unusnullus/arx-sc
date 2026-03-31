// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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

/// @title ClaimVault
/// @notice Non-custodial escrow for claimable ERC-20 transfers (hashlock coupons).
/// @dev Sender locks tokens under hashlock; receiver claims with secret; sender can refund after expiry.
contract ClaimVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Fee retained by the vault per transfer, in 6-decimal units.
    /// @dev Assumes USDC and USDT both use 6 decimals.
    uint256 public FEE_6_DECIMALS;

    /// @notice Fees collected by the vault per token (only for tokens charged as fees).
    /// @dev Used to allow safe withdrawals without touching escrowed balances.
    mapping(address => uint256) public collectedFees;

    /// @notice Owner allowed to configure swap paths.
    address public immutable owner;

    /// @notice USDC token address used as swap output for non-stable inputs.
    IERC20 public immutable USDC;
    /// @notice USDT token address (may be provided as input).
    IERC20 public immutable USDT;
    /// @notice WETH token used as the intermediate hop for swaps.
    IERC20 public immutable WETH;
    /// @notice Uniswap V3 router used to swap tokens into USDC.
    ISwapRouterV3 public immutable swapRouter;

    /// @notice Default Uniswap V3 fee tier for tokenIn -> WETH hop.
    uint24 public tokenToWethFee;
    /// @notice Default Uniswap V3 fee tier for WETH -> USDC hop.
    uint24 public wethToUsdcFee;
    /// @notice Optional per-token override fee tier for tokenIn -> WETH hop (0 means use default).
    mapping(address => uint24) public tokenToWethFeeOverride;

    struct Transfer {
        address sender;
        address token;
        uint256 amount;
        bytes32 hashlock;
        uint64 expiry;
        bool claimed;
    }

    mapping(bytes32 => Transfer) public transfers;

    /// @dev Next transfer id (incremented on each create).
    uint256 private _nextTransferId;

    event TransferCreated(
        bytes32 indexed transferId,
        address indexed sender,
        address indexed token,
        uint256 amount,
        bytes32 hashlock,
        uint64 expiry
    );
    event TransferClaimed(bytes32 indexed transferId, address indexed receiver);
    event TransferRefunded(bytes32 indexed transferId);
    event FeesSet(uint24 tokenToWethFee, uint24 wethToUsdcFee);
    event TokenToWethFeeOverrideSet(address indexed tokenIn, uint24 fee);
    event Fee6DecimalsSet(uint256 fee6Decimals);
    event CollectedFeesWithdrawn(address indexed token, address indexed to, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error ZeroFee();
    error NotOwner();
    error InvalidUSDCPath();
    error InsufficientUSDCOut();
    error InsufficientAfterFee();
    error FeesNotSet();
    error InsufficientCollectedFees();
    error TransferNotFound();
    error AlreadyClaimed();
    error HashlockMismatch();
    error Expired();
    error NotExpired();
    error NotSender();

    constructor(IERC20 usdc_, IERC20 usdt_, IERC20 weth_, ISwapRouterV3 swapRouter_) {
        if (
            address(usdc_) == address(0) || address(usdt_) == address(0)
                || address(weth_) == address(0) || address(swapRouter_) == address(0)
        ) {
            revert ZeroAddress();
        }
        owner = msg.sender;
        USDC = usdc_;
        USDT = usdt_;
        WETH = weth_;
        swapRouter = swapRouter_;
        FEE_6_DECIMALS = 3_000_000;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @notice Set default Uniswap V3 fee tiers for tokenIn->WETH and WETH->USDC hops.
    /// @dev Common tiers are 500 (0.05%), 3000 (0.30%), 10000 (1%).
    function setDefaultFees(uint24 tokenToWethFee_, uint24 wethToUsdcFee_) external onlyOwner {
        tokenToWethFee = tokenToWethFee_;
        wethToUsdcFee = wethToUsdcFee_;
        emit FeesSet(tokenToWethFee_, wethToUsdcFee_);
    }

    /// @notice Set the per-transfer fee (6 decimals).
    function setFee6Decimals(uint256 fee6Decimals) external onlyOwner {
        if (fee6Decimals == 0) revert ZeroFee();

        FEE_6_DECIMALS = fee6Decimals;

        emit Fee6DecimalsSet(fee6Decimals);
    }

    /// @notice Set per-token fee tier override for tokenIn->WETH (0 means use default).
    function setTokenToWethFeeOverride(address tokenIn, uint24 fee) external onlyOwner {
        if (tokenIn == address(0)) revert ZeroAddress();
        tokenToWethFeeOverride[tokenIn] = fee;
        emit TokenToWethFeeOverrideSet(tokenIn, fee);
    }

    /// @notice Withdraw collected fees for a given token to `to`.
    /// @dev This only withdraws amounts tracked in `collectedFees`, not arbitrary balances.
    function withdrawCollectedFees(address token, address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 available = collectedFees[token];

        if (amount > available) revert InsufficientCollectedFees();

        collectedFees[token] = available - amount;
        IERC20(token).safeTransfer(to, amount);

        emit CollectedFeesWithdrawn(token, to, amount);
    }

    /// @notice Withdraw all collected fees for a given token to `to`.
    function withdrawAllCollectedFees(address token, address to) external onlyOwner nonReentrant {
        if (token == address(0) || to == address(0)) revert ZeroAddress();

        uint256 available = collectedFees[token];

        if (available == 0) revert InsufficientCollectedFees();

        collectedFees[token] = 0;
        IERC20(token).safeTransfer(to, available);

        emit CollectedFeesWithdrawn(token, to, available);
    }

    /// @notice Return the last token in a Uniswap V3 path (the output token).
    function _lastTokenInPath(bytes memory path) internal pure returns (address token) {
        bytes memory p = path; // copy to memory for assembly
        assembly {
            let len := mload(p)
            token := shr(96, mload(add(add(p, 32), sub(len, 20))))
        }
    }

    function _pathTokenToWethToUsdc(address tokenIn) internal view returns (bytes memory path) {
        if (tokenIn == address(WETH)) {
            if (wethToUsdcFee == 0) revert FeesNotSet();
            // WETH (20) + fee (3) + USDC (20)
            path = abi.encodePacked(address(WETH), wethToUsdcFee, address(USDC));
            if (_lastTokenInPath(path) != address(USDC)) revert InvalidUSDCPath();
            return path;
        }

        uint24 fee1 = tokenToWethFeeOverride[tokenIn];
        if (fee1 == 0) fee1 = tokenToWethFee;
        if (fee1 == 0 || wethToUsdcFee == 0) revert FeesNotSet();
        // tokenIn (20) + fee (3) + WETH (20) + fee (3) + USDC (20)
        path = abi.encodePacked(tokenIn, fee1, address(WETH), wethToUsdcFee, address(USDC));
        // Sanity check: path must end in USDC
        if (_lastTokenInPath(path) != address(USDC)) revert InvalidUSDCPath();
    }

    /// @notice Ensure allowance for `spender` is at least `amount`.
    /// @dev Resets to 0 first when needed and uses SafeERC20.forceApprove to handle non-standard tokens.
    function _resetAndApprove(IERC20 token, address spender, uint256 amount) internal {
        uint256 current = token.allowance(address(this), spender);
        if (current < amount) {
            if (current > 0) token.forceApprove(spender, 0);
            token.forceApprove(spender, amount);
        }
    }

    /// @notice Create a new hashlock transfer (escrow tokens until claim or refund).
    /// @dev
    /// - If `token` is USDC: retains 3 USDC and escrows (amount - 3 USDC) in USDC.
    /// - If `token` is USDT: retains 3 USDT and escrows (amount - 3 USDT) in USDT.
    /// - Otherwise: swaps token->WETH->USDC, retains 3 USDC, escrows (usdcOut - 3 USDC) in USDC.
    /// @param hashlock keccak256(secret); claim succeeds when caller provides preimage.
    /// @param expiry Unix timestamp after which sender can refund; claim only before expiry.
    /// @return transferId Id to use for claim/refund.
    function createTransfer(address token, uint256 amount, bytes32 hashlock, uint64 expiry)
        external
        nonReentrant
        returns (bytes32 transferId)
    {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        address escrowToken;
        uint256 escrowAmount;

        if (token == address(USDC) || token == address(USDT)) {
            if (amount < FEE_6_DECIMALS) revert InsufficientUSDCOut();

            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

            escrowToken = token;
            escrowAmount = amount - FEE_6_DECIMALS;
            if (escrowAmount == 0) revert InsufficientAfterFee();
            collectedFees[token] += FEE_6_DECIMALS;
        } else {
            bytes memory path = _pathTokenToWethToUsdc(token);

            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            _resetAndApprove(IERC20(token), address(swapRouter), amount);

            uint256 usdcOut = swapRouter.exactInput(
                ISwapRouterV3.ExactInputParams({
                    path: path,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amount,
                    amountOutMinimum: FEE_6_DECIMALS + 1
                })
            );

            if (usdcOut < FEE_6_DECIMALS) revert InsufficientUSDCOut();

            escrowToken = address(USDC);
            escrowAmount = usdcOut - FEE_6_DECIMALS;

            if (escrowAmount == 0) revert InsufficientAfterFee();
            collectedFees[address(USDC)] += FEE_6_DECIMALS;
        }

        transferId = bytes32(_nextTransferId);
        _nextTransferId++;

        transfers[transferId] = Transfer({
            sender: msg.sender,
            token: escrowToken,
            amount: escrowAmount,
            hashlock: hashlock,
            expiry: expiry,
            claimed: false
        });

        emit TransferCreated(transferId, msg.sender, escrowToken, escrowAmount, hashlock, expiry);
    }

    /// @notice Claim a transfer by revealing the secret; funds go to receiver.
    /// @param transferId Id from createTransfer.
    /// @param secret Preimage such that keccak256(secret) == hashlock.
    /// @param receiver Address that receives the tokens (can be any address, e.g. new wallet).
    function claim(bytes32 transferId, bytes calldata secret, address receiver)
        external
        nonReentrant
    {
        if (receiver == address(0)) revert ZeroAddress();

        Transfer storage t = transfers[transferId];
        if (t.sender == address(0)) revert TransferNotFound();
        if (t.claimed) revert AlreadyClaimed();
        if (keccak256(secret) != t.hashlock) revert HashlockMismatch();
        if (block.timestamp >= t.expiry) revert Expired();

        t.claimed = true;
        IERC20(t.token).safeTransfer(receiver, t.amount);
        emit TransferClaimed(transferId, receiver);
    }

    /// @notice Refund an unclaimed transfer back to sender (only after expiry).
    /// @param transferId Id from createTransfer.
    function refund(bytes32 transferId) external nonReentrant {
        Transfer storage t = transfers[transferId];
        if (t.sender == address(0)) revert TransferNotFound();
        if (t.claimed) revert AlreadyClaimed();
        if (msg.sender != t.sender) revert NotSender();
        if (block.timestamp < t.expiry) revert NotExpired();

        t.claimed = true;
        IERC20(t.token).safeTransfer(t.sender, t.amount);
        emit TransferRefunded(transferId);
    }

    /// @notice Returns the current next transfer id (for off-chain indexing).
    function nextTransferId() external view returns (uint256) {
        return _nextTransferId;
    }
}
