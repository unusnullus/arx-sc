// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
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

    error ZeroAddress();

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

    function withdraw(address token, address recipient) external onlyOwner nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 bal = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(recipient, bal);
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }
}
