// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC20Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20BurnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import { ERC20PermitUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { ERC20VotesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import { AccessControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { NoncesUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import { IARX } from "./IARX.sol";

/// @title ARX Token
/// @notice ERC20 governance/utility token for the ARX ecosystem.
/// @dev Includes ERC20Permit for gasless approvals, burnable extension,
///      AccessControl to gate minting (MINTER_ROLE), and ERC20Votes for governance.
// IARX interface moved to ./token/IARX.sol

/// @title ARX ERC20 Implementation
/// @notice Minimal ERC20 with permit, votes and controlled minting via roles.
contract ARX is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IARX
{
    /// @notice Role identifier allowed to call {mint}.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Initialize proxy instance.
    /// @param admin Address that receives DEFAULT_ADMIN_ROLE and controls roles.
    function initialize(address admin) public initializer {
        __ERC20_init("ARX NET Slice", "ARX");
        __ERC20Burnable_init();
        __ERC20Permit_init("ARX NET Slice");
        __ERC20Votes_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @inheritdoc IARX
    /// @dev Reverts if caller does not have MINTER_ROLE.
    function mint(address to, uint256 amount) external override onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /// @notice ARX uses 6 decimals.
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    // --- OZ v5 Votes/Permit integration overrides ---

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }
}
