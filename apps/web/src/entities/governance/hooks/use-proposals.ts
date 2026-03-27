"use client";

import { useMemo } from "react";
import { usePublicClient, useAccount, useReadContracts } from "wagmi";

import { addressesByChain, FALLBACK_CHAIN_ID } from "@arx/config";
import { GOVERNOR_ABI } from "@arx/abi";
import { Proposal, ProposalState } from "../types";

import { useQuery } from "@tanstack/react-query";
import { parseProposalState } from "../utils";

export const useProposals = () => {
  const { chainId } = useAccount();
  const currentChainId = chainId ?? FALLBACK_CHAIN_ID;
  const governorAddress = addressesByChain[currentChainId]?.ARX_GOVERNOR;
  const publicClient = usePublicClient({ chainId: currentChainId });

  const {
    data: proposalsData,
    isLoading: isLoadingProposalsData,
    error: proposalsDataError,
  } = useQuery({
    queryKey: ["proposals-data", currentChainId, governorAddress],
    queryFn: async () => {
      if (!publicClient || !governorAddress) {
        return null;
      }

      return await publicClient.readContract({
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "getAllProposalsData",
      });
    },
    enabled: !!publicClient && !!governorAddress,
    gcTime: 5 * 60 * 1000,
    refetchInterval: 30 * 1000,
  });

  const { data: proposalEvents, isLoading: isLoadingEvents } = useQuery({
    queryKey: ["proposals-events", currentChainId, governorAddress],
    queryFn: async () => {
      if (!publicClient || !governorAddress) {
        return null;
      }

      const currentBlock = await publicClient.getBlockNumber();
      const fromBlock = BigInt(Math.max(0, Number(currentBlock) - 1000000));
      const toBlock = currentBlock;

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

      const eventsMap = new Map<
        bigint,
        {
          proposalId: bigint;
          proposer: `0x${string}`;
          targets: readonly `0x${string}`[];
          values: readonly bigint[];
          calldatas: readonly `0x${string}`[];
          description: string;
        }
      >();

      logs.forEach((log) => {
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

        if (args.proposalId) {
          eventsMap.set(args.proposalId, {
            proposalId: args.proposalId,
            proposer: args.proposer || ("0x" as `0x${string}`),
            targets: args.targets || [],
            values: args.values || [],
            calldatas: args.calldatas || [],
            description: args.description || "",
          });
        }
      });

      return eventsMap;
    },
    enabled: !!publicClient && !!governorAddress,
    gcTime: 5 * 60 * 1000,
    refetchInterval: 30 * 1000,
  });

  const proposalIds = useMemo(() => {
    if (!proposalsData) return [];
    return proposalsData.map((p) => p.id);
  }, [proposalsData]);

  const contracts = useMemo(() => {
    if (proposalIds.length === 0) return [];

    return [
      {
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "stateBatch",
        args: [proposalIds],
      },
      ...proposalIds.flatMap((id) => [
        {
          address: governorAddress,
          abi: GOVERNOR_ABI,
          functionName: "proposalDeadline",
          args: [id],
        },
        {
          address: governorAddress,
          abi: GOVERNOR_ABI,
          functionName: "proposalEta",
          args: [id],
        },
      ]),
    ];
  }, [proposalIds, governorAddress]);

  const { data: proposalStates, isLoading: isLoadingStates } = useReadContracts(
    {
      contracts,
      query: {
        enabled: proposalIds.length > 0 && !!governorAddress,
      },
    },
  );

  const proposals: Proposal[] = useMemo(() => {
    if (!proposalsData || proposalsData.length === 0) {
      return [];
    }

    const states = proposalStates?.[0]?.result as number[] | undefined;
    const deadlines = proposalIds.map(
      (_, index) =>
        proposalStates?.[1 + index * 2]?.result as bigint | undefined,
    );
    const etas = proposalIds.map(
      (_, index) =>
        proposalStates?.[2 + index * 2]?.result as bigint | undefined,
    );

    return proposalsData.map((proposalData, index) => {
      const state = states?.[index];
      const deadline = deadlines[index];
      const eta = etas[index];
      const eventData = proposalEvents?.get(proposalData.id);

      return {
        id: proposalData.id,
        proposer:
          eventData?.proposer || (proposalData.proposer as `0x${string}`),
        targets: eventData?.targets || [],
        values: eventData?.values || [],
        calldatas: eventData?.calldatas || [],
        description: eventData?.description || "",
        descriptionHash: "0x" as `0x${string}`,
        state:
          state !== undefined
            ? parseProposalState(state)
            : ProposalState.Pending,
        snapshot: proposalData.startBlock,
        deadline: deadline ?? proposalData.endBlock,
        eta,
      };
    });
  }, [proposalsData, proposalStates, proposalIds, proposalEvents]);

  return {
    proposals: proposals.sort((a, b) => {
      if (a.id > b.id) return -1;
      if (a.id < b.id) return 1;
      return 0;
    }),
    isLoading: isLoadingProposalsData || isLoadingStates || isLoadingEvents,
    error: proposalsDataError,
  };
};
