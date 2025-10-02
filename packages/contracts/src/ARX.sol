// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title ARX Token
/// @notice ERC20 governance/utility token for the ARX ecosystem.
/// @dev Includes ERC20Permit for gasless approvals, burnable extension,
///      and AccessControl to gate minting to the sale contract (MINTER_ROLE).
interface IARX {
    /// @notice Mints `amount` tokens to `to`.
    /// @dev Intended to be called by sale contracts that hold MINTER_ROLE.
    /// @param to Recipient address.
    /// @param amount Amount of tokens to mint (18 decimals).
    function mint(address to, uint256 amount) external;
}

/// @title ARX ERC20 Implementation
/// @notice Minimal ERC20 with permit and controlled minting via roles.
contract ARX is ERC20, ERC20Burnable, ERC20Permit, AccessControl, IARX {
    /// @notice Role identifier allowed to call {mint}.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @param admin Address that receives DEFAULT_ADMIN_ROLE and controls roles.
    constructor(address admin) ERC20("ARX", "ARX") ERC20Permit("ARX") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @inheritdoc IARX
    /// @dev Reverts if caller does not have MINTER_ROLE.
    function mint(address to, uint256 amount) external override onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
