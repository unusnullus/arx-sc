// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @title ArxMultiTokenMerkleClaim
/// @notice Upgradeable contract for claiming ERC20 tokens using Merkle proofs.
/// @dev Supports multiple Merkle roots per token and tracks claims per (user, root).
contract ArxMultiTokenMerkleClaim is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    event MerkleRootAdded(address indexed token, bytes32 indexed root);
    event TokensClaimed(
        address indexed user, address indexed token, uint256 amount, bytes32 indexed merkleRoot
    );

    mapping(address => bytes32[]) public merkleRoots;
    address[] public tokenList;
    mapping(address => mapping(bytes32 => uint256)) public claimed;

    /// @notice Mapping from merkle root to metadata (description or URI).
    mapping(bytes32 => string) public merkleRootDetails;

    error ZeroAddress();

    /// @notice Structure for merkle root details.
    struct MerkleRootInfo {
        bytes32 root;
        string details;
    }

    function initialize(address owner_) public initializer {
        if (owner_ == address(0)) revert ZeroAddress();
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    function addMerkleRoot(address token, bytes32 root) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (merkleRoots[token].length == 0) tokenList.push(token);
        merkleRoots[token].push(root);
        emit MerkleRootAdded(token, root);
    }

    /// @notice Add merkle root with metadata description.
    /// @param token Token address.
    /// @param root Merkle root.
    /// @param details Description or metadata URI for this root.
    function addMerkleRootWithDetails(address token, bytes32 root, string calldata details)
        external
        onlyOwner
    {
        if (token == address(0)) revert ZeroAddress();
        if (merkleRoots[token].length == 0) tokenList.push(token);
        merkleRoots[token].push(root);
        merkleRootDetails[root] = details;
        emit MerkleRootAdded(token, root);
    }

    /// @notice Update metadata for an existing merkle root.
    /// @param root Merkle root.
    /// @param details Description or metadata URI.
    function setMerkleRootDetails(bytes32 root, string calldata details) external onlyOwner {
        merkleRootDetails[root] = details;
    }

    function getMerkleRoots(address token) external view returns (bytes32[] memory) {
        return merkleRoots[token];
    }

    function claim(address token, uint256 totalAmount, bytes32[] calldata proof)
        external
        nonReentrant
        returns (uint256 amountToClaim)
    {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, totalAmount));
        bytes32 usedRoot;
        bool valid;
        bytes32[] storage roots = merkleRoots[token];
        for (uint256 i = 0; i < roots.length; i++) {
            if (MerkleProof.verify(proof, roots[i], leaf)) {
                usedRoot = roots[i];
                valid = true;
                break;
            }
        }
        require(valid, "Invalid proof");

        uint256 claimedAmount = claimed[msg.sender][usedRoot];
        require(claimedAmount < totalAmount, "Already claimed");

        amountToClaim = totalAmount - claimedAmount;
        claimed[msg.sender][usedRoot] = totalAmount;
        IERC20(token).safeTransfer(msg.sender, amountToClaim);
        emit TokensClaimed(msg.sender, token, amountToClaim, usedRoot);
    }

    function getTotalClaimedForToken(address user, address token)
        external
        view
        returns (uint256 totalClaimed)
    {
        bytes32[] storage roots = merkleRoots[token];
        for (uint256 i = 0; i < roots.length; i++) {
            totalClaimed += claimed[user][roots[i]];
        }
    }

    function getClaimedForTokenAndRoot(address user, bytes32 merkleRoot)
        external
        view
        returns (uint256)
    {
        return claimed[user][merkleRoot];
    }

    function getTotalClaimedForAllTokens(address user)
        external
        view
        returns (uint256 totalClaimed)
    {
        for (uint256 i = 0; i < tokenList.length; i++) {
            address token = tokenList[i];
            bytes32[] storage roots = merkleRoots[token];
            for (uint256 j = 0; j < roots.length; j++) {
                totalClaimed += claimed[user][roots[j]];
            }
        }
    }

    /// @notice Check if a claim has been made for a token and root index.
    /// @param token Token address.
    /// @param rootIndex Index of the merkle root in the token's root array.
    /// @param user User address to check.
    /// @return True if the user has claimed for this root.
    function isClaimed(address token, uint256 rootIndex, address user)
        external
        view
        returns (bool)
    {
        bytes32[] storage roots = merkleRoots[token];
        if (rootIndex >= roots.length) {
            return false;
        }
        bytes32 root = roots[rootIndex];
        return claimed[user][root] > 0;
    }

    /// @notice Get details (description/metadata) for a merkle root.
    /// @param root Merkle root.
    /// @return details Description or metadata URI associated with the root.
    function getMerkleRootDetails(bytes32 root) external view returns (string memory details) {
        return merkleRootDetails[root];
    }

    /// @notice Get all merkle roots with their details for a token.
    /// @param token Token address.
    /// @return roots Array of merkle roots.
    /// @return infos Array of MerkleRootInfo structs with root and details.
    function getMerkleRootsWithDetails(address token)
        external
        view
        returns (bytes32[] memory roots, MerkleRootInfo[] memory infos)
    {
        roots = merkleRoots[token];
        infos = new MerkleRootInfo[](roots.length);
        for (uint256 i = 0; i < roots.length; i++) {
            infos[i] = MerkleRootInfo({ root: roots[i], details: merkleRootDetails[roots[i]] });
        }
    }

    function withdraw(address token, address recipient) external onlyOwner nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 bal = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(recipient, bal);
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }
}
