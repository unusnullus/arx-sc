// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title ClaimVault
/// @notice Non-custodial escrow for claimable ERC-20 transfers (hashlock coupons).
/// @dev Sender locks tokens under hashlock; receiver claims with secret; sender can refund after expiry.
contract ClaimVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

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

    error ZeroAddress();
    error ZeroAmount();
    error TransferNotFound();
    error AlreadyClaimed();
    error HashlockMismatch();
    error Expired();
    error NotExpired();
    error NotSender();

    /// @notice Create a new hashlock transfer (escrow tokens until claim or refund).
    /// @param token ERC-20 token address.
    /// @param amount Amount to escrow.
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

        transferId = bytes32(_nextTransferId);
        _nextTransferId++;

        transfers[transferId] = Transfer({
            sender: msg.sender,
            token: token,
            amount: amount,
            hashlock: hashlock,
            expiry: expiry,
            claimed: false
        });

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit TransferCreated(transferId, msg.sender, token, amount, hashlock, expiry);
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
