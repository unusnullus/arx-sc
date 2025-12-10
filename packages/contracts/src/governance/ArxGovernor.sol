// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    GovernorUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {
    GovernorCountingSimpleUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {
    GovernorVotesUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import {
    GovernorVotesQuorumFractionUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import {
    GovernorTimelockControlUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import {
    TimelockControllerUpgradeable
} from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
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
    error ZeroAddress();
    error InvalidParameter();

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
        if (address(token) == address(0)) revert ZeroAddress();
        if (address(timelock) == address(0)) revert ZeroAddress();
        if (quorumPercent == 0 || quorumPercent > 100) {
            revert InvalidParameter();
        }
        if (votingPeriodBlocks == 0) revert InvalidParameter();
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

    // Storage for all proposal IDs
    uint256[] private _proposalIds;

    /// @notice Vote receipt structure for tracking individual votes.
    struct VoteReceipt {
        bool hasVoted;
        uint8 support; // 0 = Against, 1 = For, 2 = Abstain
        uint256 votes;
    }

    /// @notice Proposal info data structure.
    struct ProposalInfo {
        uint256 id;
        address proposer;
        uint256 startBlock;
        uint256 endBlock;
    }

    /// @notice Mapping from proposalId => voter => VoteReceipt
    mapping(uint256 => mapping(address => VoteReceipt)) private _voteReceipts;

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
        uint256 proposalId = super.propose(targets, values, calldatas, description);
        _proposalIds.push(proposalId);
        return proposalId;
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
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint256) {
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

    /// @notice Get all proposal IDs that have been created.
    /// @return Array of all proposal IDs.
    function getAllProposals() public view returns (uint256[] memory) {
        return _proposalIds;
    }

    /// @notice Get the total number of proposals created.
    /// @return The count of proposals.
    function proposalCount() public view returns (uint256) {
        return _proposalIds.length;
    }

    /// @notice Get proposal IDs in a range (useful for pagination).
    /// @param offset Starting index (0-based).
    /// @param limit Maximum number of proposals to return.
    /// @return Array of proposal IDs.
    function getProposals(uint256 offset, uint256 limit) public view returns (uint256[] memory) {
        uint256 length = _proposalIds.length;
        if (offset >= length) {
            return new uint256[](0);
        }

        uint256 end = offset + limit;
        if (end > length) {
            end = length;
        }

        uint256[] memory result = new uint256[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = _proposalIds[i];
        }
        return result;
    }

    /// @notice Override _countVote to store vote receipt data.
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight,
        bytes memory params
    ) internal override(GovernorUpgradeable, GovernorCountingSimpleUpgradeable) returns (uint256) {
        uint256 result = super._countVote(proposalId, account, support, weight, params);

        // Store vote receipt
        _voteReceipts[proposalId][account] =
            VoteReceipt({ hasVoted: true, support: support, votes: weight });

        return result;
    }

    /// @notice Get vote receipt for a specific voter on a proposal.
    /// @param proposalId The proposal ID.
    /// @param voter The voter address.
    /// @return receipt The vote receipt containing hasVoted, support, and votes.
    function getVoteReceipt(uint256 proposalId, address voter)
        public
        view
        returns (VoteReceipt memory receipt)
    {
        receipt = _voteReceipts[proposalId][voter];
        // If not found in mapping, check using hasVoted (for backward compatibility)
        if (!receipt.hasVoted) {
            receipt.hasVoted = hasVoted(proposalId, voter);
        }
        return receipt;
    }

    /// @notice Get proposal info data for multiple proposals.
    /// @param offset Starting index (0-based).
    /// @param limit Maximum number of proposals to return.
    /// @return proposals Array of ProposalInfo structs.
    function getProposalsData(uint256 offset, uint256 limit)
        public
        view
        returns (ProposalInfo[] memory proposals)
    {
        uint256 length = _proposalIds.length;
        if (offset >= length) {
            return new ProposalInfo[](0);
        }

        uint256 end = offset + limit;
        if (end > length) {
            end = length;
        }

        proposals = new ProposalInfo[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            uint256 proposalId = _proposalIds[i];
            proposals[i - offset] = ProposalInfo({
                id: proposalId,
                proposer: proposalProposer(proposalId),
                startBlock: proposalSnapshot(proposalId),
                endBlock: proposalDeadline(proposalId)
            });
        }
        return proposals;
    }

    /// @notice Get proposal info data for all proposals.
    /// @return proposals Array of ProposalInfo structs.
    function getAllProposalsData() public view returns (ProposalInfo[] memory proposals) {
        uint256 length = _proposalIds.length;
        proposals = new ProposalInfo[](length);
        for (uint256 i = 0; i < length; i++) {
            uint256 proposalId = _proposalIds[i];
            proposals[i] = ProposalInfo({
                id: proposalId,
                proposer: proposalProposer(proposalId),
                startBlock: proposalSnapshot(proposalId),
                endBlock: proposalDeadline(proposalId)
            });
        }
        return proposals;
    }

    /// @notice Get state for multiple proposals in a single call.
    /// @param proposalIds Array of proposal IDs to query.
    /// @return states Array of proposal states corresponding to the input IDs.
    function stateBatch(uint256[] memory proposalIds)
        public
        view
        returns (ProposalState[] memory states)
    {
        states = new ProposalState[](proposalIds.length);
        for (uint256 i = 0; i < proposalIds.length; i++) {
            states[i] = state(proposalIds[i]);
        }
        return states;
    }

    function _authorizeUpgrade(address) internal override onlyGovernance { }
}
