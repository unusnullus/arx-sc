// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { GovernorUpgradeable } from
    "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import { GovernorCountingSimpleUpgradeable } from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import { GovernorVotesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import { GovernorVotesQuorumFractionUpgradeable } from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import { GovernorTimelockControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import { TimelockControllerUpgradeable } from
    "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/// @title ArxGovernor
/// @notice Upgradeable Governor for ARX using ERC20Votes and TimelockControl.
contract ArxGovernor is
    Initializable,
    GovernorUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorTimelockControlUpgradeable,
    UUPSUpgradeable
{
    /// @notice Initialize governor.
    /// @param token Votes token (ARX proxy implementing ERC20Votes).
    /// @param timelock Timelock controller proxy.
    /// @param quorumPercent Quorum fraction in percentage (e.g., 4 for 4%).
    /// @param votingDelayBlocks Delay (in blocks) before voting starts.
    /// @param votingPeriodBlocks Voting period length in blocks.
    function initialize(
        IVotes token,
        TimelockControllerUpgradeable timelock,
        uint256 quorumPercent,
        uint256 votingDelayBlocks,
        uint256 votingPeriodBlocks
    ) public initializer {
        __Governor_init("ArxGovernor");
        __GovernorCountingSimple_init();
        __GovernorVotes_init(token);
        __GovernorVotesQuorumFraction_init(quorumPercent);
        __GovernorTimelockControl_init(timelock);
        __UUPSUpgradeable_init();
        _votingDelay = votingDelayBlocks;
        _votingPeriod = votingPeriodBlocks;
    }

    // Expose voting params via storage to allow initialization
    uint256 internal _votingDelay;
    uint256 internal _votingPeriod;

    function votingDelay() public view override returns (uint256) {
        return _votingDelay;
    }

    function votingPeriod() public view override returns (uint256) {
        return _votingPeriod;
    }

    // Required overrides for Solidity/OZ multiple inheritance

    function quorum(uint256 blockNumber)
        public
        view
        override(GovernorUpgradeable, GovernorVotesQuorumFractionUpgradeable)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(GovernorUpgradeable) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(GovernorUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address) internal override onlyGovernance { }
}
