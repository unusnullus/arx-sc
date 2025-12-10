// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {
    ERC1967Proxy
} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ArxGovernor} from "../src/governance/ArxGovernor.sol";
import {ArxTimelock} from "../src/governance/ArxTimelock.sol";
import {ARX} from "../src/token/ARX.sol";
import {IARX} from "../src/token/IARX.sol";

contract ArxGovernorTest is Test {
    ARX arx;
    ArxTimelock timelock;
    ArxGovernor governor;
    address admin = address(0xA11CE);
    address proposer = address(0xBEEF);
    address executor = address(0xCAFE);
    address voter = address(0xDADA);
    uint256 quorumPercent = 4; // 4%
    uint256 votingDelay = 1;
    uint256 votingPeriod = 10;

    function setUp() public {
        vm.startPrank(admin);

        // Deploy ARX
        ARX arxImpl = new ARX();
        bytes memory dataArx = abi.encodeWithSelector(
            ARX.initialize.selector,
            admin,
            address(0), // tokenSale
            address(0), // uniswapRouter
            address(0), // usdcToken
            address(0)  // wethToken
        );
        ERC1967Proxy arxProxy = new ERC1967Proxy(address(arxImpl), dataArx);
        arx = ARX(address(arxProxy));

        // Deploy Timelock
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        address[] memory executors = new address[](1);
        executors[0] = executor;

        ArxTimelock timelockImpl = new ArxTimelock();
        bytes memory dataTimelock = abi.encodeWithSelector(
            ArxTimelock.initialize.selector,
            1 days, // minDelay
            proposers,
            executors,
            admin
        );
        ERC1967Proxy timelockProxy = new ERC1967Proxy(
            address(timelockImpl),
            dataTimelock
        );
        timelock = ArxTimelock(payable(address(timelockProxy)));

        // Deploy Governor
        ArxGovernor governorImpl = new ArxGovernor();
        bytes memory dataGovernor = abi.encodeWithSelector(
            ArxGovernor.initialize.selector,
            arx,
            timelock,
            quorumPercent,
            votingDelay,
            votingPeriod
        );
        ERC1967Proxy governorProxy = new ERC1967Proxy(
            address(governorImpl),
            dataGovernor
        );
        governor = ArxGovernor(payable(address(governorProxy)));

        // Grant roles (admin has DEFAULT_ADMIN_ROLE)
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        // Fund voter
        arx.grantRole(arx.MINTER_ROLE(), admin);
        arx.mint(voter, 100_000_000); // 100 ARX

        vm.stopPrank();

        vm.prank(voter);
        arx.delegate(voter);
    }

    function test_Initialize() public {
        assertEq(address(governor.token()), address(arx));
        assertEq(governor.votingDelay(), votingDelay);
        assertEq(governor.votingPeriod(), votingPeriod);
        assertEq(governor.quorumNumerator(), quorumPercent);
    }

    function test_Propose() public {
        address[] memory targets = new address[](1);
        targets[0] = address(arx);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            arx.mint.selector,
            voter,
            1_000_000
        );
        string memory description = "Test proposal";

        vm.prank(voter);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        assertGt(proposalId, 0);
        // ProposalState is an enum from GovernorUpgradeable
        assertEq(uint256(governor.state(proposalId)), 0); // 0 = Pending
    }

    function test_Vote() public {
        // Create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(arx);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            arx.mint.selector,
            voter,
            1_000_000
        );
        string memory description = "Test proposal";

        vm.prank(voter);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        // Move to voting period
        vm.roll(block.number + votingDelay + 1);

        // Vote
        vm.prank(voter);
        governor.castVote(proposalId, 1); // For

        (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        ) = governor.proposalVotes(proposalId);
        assertEq(forVotes, arx.getVotes(voter));
    }

    function test_RevertWhen_Initialize_ZeroToken() public {
        ArxGovernor impl = new ArxGovernor();
        bytes memory data = abi.encodeWithSelector(
            ArxGovernor.initialize.selector,
            address(0), // Zero token
            timelock,
            quorumPercent,
            votingDelay,
            votingPeriod
        );
        vm.expectRevert(ArxGovernor.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), data);
    }

    function test_RevertWhen_Initialize_ZeroTimelock() public {
        ArxGovernor impl = new ArxGovernor();
        bytes memory data = abi.encodeWithSelector(
            ArxGovernor.initialize.selector,
            arx,
            address(0), // Zero timelock
            quorumPercent,
            votingDelay,
            votingPeriod
        );
        vm.expectRevert(ArxGovernor.ZeroAddress.selector);
        new ERC1967Proxy(address(impl), data);
    }

    function test_RevertWhen_Initialize_InvalidQuorum() public {
        ArxGovernor impl = new ArxGovernor();
        bytes memory data = abi.encodeWithSelector(
            ArxGovernor.initialize.selector,
            arx,
            timelock,
            101, // Invalid: > 100
            votingDelay,
            votingPeriod
        );
        vm.expectRevert(ArxGovernor.InvalidParameter.selector);
        new ERC1967Proxy(address(impl), data);
    }

    function test_RevertWhen_Initialize_ZeroVotingPeriod() public {
        ArxGovernor impl = new ArxGovernor();
        bytes memory data = abi.encodeWithSelector(
            ArxGovernor.initialize.selector,
            arx,
            timelock,
            quorumPercent,
            votingDelay,
            0 // Invalid: zero voting period
        );
        vm.expectRevert(ArxGovernor.InvalidParameter.selector);
        new ERC1967Proxy(address(impl), data);
    }

    function test_QuorumCalculation() public {
        // Move forward a block to ensure we have past blocks
        vm.roll(block.number + 1);
        // Use a past block number to avoid ERC5805FutureLookup error
        uint256 blockNumber = block.number - 1;
        uint256 quorum = governor.quorum(blockNumber);
        // Quorum should be 4% of total supply at that block
        // Get past votes (at blockNumber)
        uint256 pastVotes = arx.getPastTotalSupply(blockNumber);
        uint256 expectedQuorum = (pastVotes * quorumPercent) / 100;
        assertEq(quorum, expectedQuorum);
    }

    function test_GetAllProposals() public {
        // Initially no proposals
        assertEq(governor.proposalCount(), 0);
        uint256[] memory allProposals = governor.getAllProposals();
        assertEq(allProposals.length, 0);

        // Create first proposal
        address[] memory targets = new address[](1);
        targets[0] = address(arx);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            arx.mint.selector,
            voter,
            1_000_000
        );
        string memory description = "First proposal";

        vm.prank(voter);
        uint256 proposalId1 = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        // Check proposal count
        assertEq(governor.proposalCount(), 1);
        allProposals = governor.getAllProposals();
        assertEq(allProposals.length, 1);
        assertEq(allProposals[0], proposalId1);

        // Create second proposal
        vm.prank(voter);
        uint256 proposalId2 = governor.propose(
            targets,
            values,
            calldatas,
            "Second proposal"
        );

        // Check proposal count
        assertEq(governor.proposalCount(), 2);
        allProposals = governor.getAllProposals();
        assertEq(allProposals.length, 2);
        assertEq(allProposals[0], proposalId1);
        assertEq(allProposals[1], proposalId2);
    }

    function test_GetProposals() public {
        // Create multiple proposals
        address[] memory targets = new address[](1);
        targets[0] = address(arx);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            arx.mint.selector,
            voter,
            1_000_000
        );

        vm.startPrank(voter);
        uint256 proposalId1 = governor.propose(
            targets,
            values,
            calldatas,
            "Proposal 1"
        );
        uint256 proposalId2 = governor.propose(
            targets,
            values,
            calldatas,
            "Proposal 2"
        );
        uint256 proposalId3 = governor.propose(
            targets,
            values,
            calldatas,
            "Proposal 3"
        );
        vm.stopPrank();

        // Test pagination - get first 2 proposals
        uint256[] memory proposals = governor.getProposals(0, 2);
        assertEq(proposals.length, 2);
        assertEq(proposals[0], proposalId1);
        assertEq(proposals[1], proposalId2);

        // Test pagination - get next 2 proposals
        proposals = governor.getProposals(2, 2);
        assertEq(proposals.length, 1);
        assertEq(proposals[0], proposalId3);

        // Test pagination - offset beyond length
        proposals = governor.getProposals(10, 2);
        assertEq(proposals.length, 0);

        // Test pagination - limit exceeds available
        proposals = governor.getProposals(0, 10);
        assertEq(proposals.length, 3);
    }

    function test_GetVoteReceipt() public {
        // Create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(arx);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(arx.mint.selector, voter, 1_000_000);
        string memory description = "Test proposal";

        vm.prank(voter);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // Move to voting period
        vm.roll(block.number + votingDelay + 1);

        // Vote
        vm.prank(voter);
        governor.castVote(proposalId, 1); // For

        // Get vote receipt
        ArxGovernor.VoteReceipt memory receipt = governor.getVoteReceipt(proposalId, voter);
        assertTrue(receipt.hasVoted);
        assertEq(receipt.support, 1); // For
        assertEq(receipt.votes, arx.getVotes(voter));
    }

    function test_GetVoteReceipt_NoVote() public {
        // Create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(arx);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(arx.mint.selector, voter, 1_000_000);

        vm.prank(voter);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Test");

        // Get vote receipt for non-voter
        ArxGovernor.VoteReceipt memory receipt = governor.getVoteReceipt(proposalId, address(0x999));
        assertFalse(receipt.hasVoted);
        assertEq(receipt.support, 0);
        assertEq(receipt.votes, 0);
    }

    function test_GetProposalsData() public {
        // Create proposals
        address[] memory targets = new address[](1);
        targets[0] = address(arx);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(arx.mint.selector, voter, 1_000_000);

        vm.startPrank(voter);
        uint256 proposalId1 = governor.propose(targets, values, calldatas, "Proposal 1");
        uint256 proposalId2 = governor.propose(targets, values, calldatas, "Proposal 2");
        vm.stopPrank();

        // Get proposals data
        ArxGovernor.ProposalInfo[] memory proposals = governor.getProposalsData(0, 2);
        assertEq(proposals.length, 2);
        assertEq(proposals[0].id, proposalId1);
        assertEq(proposals[1].id, proposalId2);
        assertEq(proposals[0].proposer, voter);
        assertEq(proposals[1].proposer, voter);
    }

    function test_GetAllProposalsData() public {
        // Create proposals
        address[] memory targets = new address[](1);
        targets[0] = address(arx);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(arx.mint.selector, voter, 1_000_000);

        vm.startPrank(voter);
        uint256 proposalId1 = governor.propose(targets, values, calldatas, "Proposal 1");
        uint256 proposalId2 = governor.propose(targets, values, calldatas, "Proposal 2");
        vm.stopPrank();

        // Get all proposals data
        ArxGovernor.ProposalInfo[] memory proposals = governor.getAllProposalsData();
        assertEq(proposals.length, 2);
        assertEq(proposals[0].id, proposalId1);
        assertEq(proposals[1].id, proposalId2);
    }

    function test_StateBatch() public {
        // Create proposals
        address[] memory targets = new address[](1);
        targets[0] = address(arx);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(arx.mint.selector, voter, 1_000_000);

        vm.startPrank(voter);
        uint256 proposalId1 = governor.propose(targets, values, calldatas, "Proposal 1");
        uint256 proposalId2 = governor.propose(targets, values, calldatas, "Proposal 2");
        vm.stopPrank();

        // Get states in batch
        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0] = proposalId1;
        proposalIds[1] = proposalId2;
        
        ArxGovernor.ProposalState[] memory states = governor.stateBatch(proposalIds);
        assertEq(uint256(states[0]), 0); // Pending
        assertEq(uint256(states[1]), 0); // Pending
    }

    function test_CastVoteWithReason() public {
        // Create proposal
        address[] memory targets = new address[](1);
        targets[0] = address(arx);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(arx.mint.selector, voter, 1_000_000);

        vm.prank(voter);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Test");

        // Move to voting period
        vm.roll(block.number + votingDelay + 1);

        // Vote with reason
        vm.prank(voter);
        governor.castVoteWithReason(proposalId, 1, "I support this proposal");

        ArxGovernor.VoteReceipt memory receipt = governor.getVoteReceipt(proposalId, voter);
        assertTrue(receipt.hasVoted);
        assertEq(receipt.support, 1);
    }

    function test_CastVote_Against() public {
        address[] memory targets = new address[](1);
        targets[0] = address(arx);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(arx.mint.selector, voter, 1_000_000);

        vm.prank(voter);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Test");

        vm.roll(block.number + votingDelay + 1);

        vm.prank(voter);
        governor.castVote(proposalId, 0); // Against

        ArxGovernor.VoteReceipt memory receipt = governor.getVoteReceipt(proposalId, voter);
        assertEq(receipt.support, 0);
    }

    function test_CastVote_Abstain() public {
        address[] memory targets = new address[](1);
        targets[0] = address(arx);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(arx.mint.selector, voter, 1_000_000);

        vm.prank(voter);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Test");

        vm.roll(block.number + votingDelay + 1);

        vm.prank(voter);
        governor.castVote(proposalId, 2); // Abstain

        ArxGovernor.VoteReceipt memory receipt = governor.getVoteReceipt(proposalId, voter);
        assertEq(receipt.support, 2);
    }
}
