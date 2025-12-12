"use client";

import { useMemo } from "react";
import { useAccount, useReadContracts, useBlockNumber } from "wagmi";
import { keccak256, toBytes } from "viem";

import { addressesByChain, FALLBACK_CHAIN_ID } from "@arx/config";
import { GOVERNOR_ABI } from "@arx/abi";
import { Proposal, ProposalState } from "../types";
import { parseProposalState } from "../utils";
import { usePublicClient } from "wagmi";
import { useQuery } from "@tanstack/react-query";

export const useProposalDetails = (proposalId: bigint) => {
  const { chainId, address } = useAccount();
  const currentChainId = chainId ?? FALLBACK_CHAIN_ID;
  const governorAddress = addressesByChain[currentChainId]?.ARX_GOVERNOR;
  const publicClient = usePublicClient({ chainId: currentChainId });
  const { data: blockNumber } = useBlockNumber({
    chainId: currentChainId,
  });

  const { data: proposalData } = useQuery({
    queryKey: [
      "proposal-details",
      currentChainId,
      governorAddress,
      proposalId.toString(),
    ],
    queryFn: async () => {
      if (!publicClient || !governorAddress) {
        return null;
      }

      const allProposals = await publicClient.readContract({
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "getAllProposalsData",
      });

      const proposalExists = allProposals.some(
        (p) => Number(p.id) === Number(proposalId),
      );

      console.log(proposalExists);
      if (!proposalExists) {
        return null;
      }

      const proposalInfo = allProposals.find(
        (p) => Number(p.id) === Number(proposalId),
      );
      const startBlock = proposalInfo?.startBlock;

      const currentBlock = await publicClient.getBlockNumber();
      let fromBlock: bigint;
      let toBlock: bigint;

      if (startBlock) {
        fromBlock = BigInt(Math.max(0, Number(startBlock) - 1000));
        toBlock = BigInt(
          Math.min(Number(currentBlock), Number(startBlock) + 1000),
        );
      } else {
        fromBlock = BigInt(Math.max(0, Number(currentBlock) - 2000000));
        toBlock = currentBlock;
      }

      const proposalCreatedEvent = GOVERNOR_ABI.find(
        (item) => item.type === "event" && item.name === "ProposalCreated",
      );

      if (!proposalCreatedEvent) {
        return null;
      }

      const logs = await publicClient.getLogs({
        address: governorAddress,
        event: proposalCreatedEvent,
        fromBlock,
        toBlock,
      });

      const log = logs.find((l) => {
        const args = l.args as { proposalId?: bigint };
        return args.proposalId === proposalId;
      });

      if (!log) {
        if (proposalInfo) {
          return {
            proposalId: proposalInfo.id,
            proposer: proposalInfo.proposer as `0x${string}`,
            targets: [],
            values: [],
            calldatas: [],
            snapshot: proposalInfo.startBlock,
            deadline: proposalInfo.endBlock,
            description: "",
            descriptionHash: "0x" as `0x${string}`,
          };
        }
        return null;
      }

      const args = log.args as {
        proposalId?: bigint;
        proposer?: `0x${string}`;
        targets?: readonly `0x${string}`[];
        values?: readonly bigint[];
        signatures?: readonly string[];
        calldatas?: readonly `0x${string}`[];
        voteStart?: bigint;
        voteEnd?: bigint;
        description?: string;
      };

      const descriptionHash = keccak256(toBytes(args.description || ""));

      return {
        proposalId: args.proposalId || BigInt(0),
        proposer: args.proposer || ("0x" as `0x${string}`),
        targets: args.targets || [],
        values: args.values || [],
        calldatas: args.calldatas || [],
        snapshot: args.voteStart || BigInt(0),
        deadline: args.voteEnd || BigInt(0),
        description: args.description || "",
        descriptionHash: descriptionHash as `0x${string}`,
      };
    },
    enabled: !!publicClient && !!governorAddress && !!proposalId,
    gcTime: 5 * 60 * 1000,
  });

  const contracts = useMemo(() => {
    if (!governorAddress) return [];
    return [
      {
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "state",
        args: [proposalId],
      },
      {
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "proposalSnapshot",
        args: [proposalId],
      },
      {
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "proposalDeadline",
        args: [proposalId],
      },
      {
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "proposalEta",
        args: [proposalId],
      },
      {
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "proposalVotes",
        args: [proposalId],
      },
      {
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "quorum",
        args: blockNumber ? [blockNumber] : undefined,
      },
      ...(address
        ? [
            {
              address: governorAddress,
              abi: GOVERNOR_ABI,
              functionName: "getVoteReceipt",
              args: [proposalId, address],
            },
          ]
        : []),
    ];
  }, [governorAddress, proposalId, blockNumber, address]);

  const { data, isLoading } = useReadContracts({
    contracts: contracts as readonly unknown[],
    query: {
      enabled: !!governorAddress && !!proposalId && !!blockNumber,
    },
  });

  const proposal = useMemo(() => {
    if (!proposalData || !data) {
      return undefined;
    }

    const state = data[0]?.result as number | undefined;
    const snapshot = data[1]?.result as bigint | undefined;
    const deadline = data[2]?.result as bigint | undefined;
    const eta = data[3]?.result as bigint | undefined;

    return {
      id: proposalData.proposalId,
      proposer: proposalData.proposer,
      targets: proposalData.targets,
      values: proposalData.values,
      calldatas: proposalData.calldatas,
      description: proposalData.description,
      descriptionHash: proposalData.descriptionHash,
      state:
        state !== undefined ? parseProposalState(state) : ProposalState.Pending,
      snapshot: snapshot ?? proposalData.snapshot,
      deadline: deadline ?? proposalData.deadline,
      eta,
    };
  }, [proposalData, data]) as Proposal | undefined;

  const votes = useMemo(() => {
    if (!data || data[4]?.status !== "success") {
      return undefined;
    }
    const votesData = data[4]?.result as [bigint, bigint, bigint] | undefined;
    if (!votesData) return undefined;
    return {
      againstVotes: votesData[0] || BigInt(0),
      forVotes: votesData[1] || BigInt(0),
      abstainVotes: votesData[2] || BigInt(0),
    };
  }, [data]);

  const quorum = useMemo(() => {
    if (!data || data[5]?.status !== "success") {
      return undefined;
    }
    return data?.[5]?.result as bigint | undefined;
  }, [data]);

  const userVoteReceipt = useMemo(() => {
    if (!address || !data || data[6]?.status !== "success") {
      return undefined;
    }
    const receipt = data[6]?.result as
      | { hasVoted: boolean; support: number; votes: bigint }
      | undefined;
    return receipt;
  }, [data, address]);

  console.log(proposal);

  return {
    proposal,
    votes,
    quorum,
    userVoteReceipt,
    isLoading,
  };
};
