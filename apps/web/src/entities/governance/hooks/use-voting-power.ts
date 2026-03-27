"use client";

import { useMemo } from "react";
import { useAccount, useBlockNumber, useReadContract } from "wagmi";
import { formatUnits } from "viem";

import { addressesByChain, FALLBACK_CHAIN_ID } from "@arx/config";
import { ARX_ABI, GOVERNOR_ABI } from "@arx/abi";

export const useVotingPower = () => {
  const { address, chainId } = useAccount();
  const currentChainId = chainId ?? FALLBACK_CHAIN_ID;
  const arxAddress = addressesByChain[currentChainId]?.ARX;
  const governorAddress = addressesByChain[currentChainId]?.ARX_GOVERNOR;

  const { data: blockNumber, refetch: refetchBlockNumber } = useBlockNumber({
    chainId: currentChainId,
  });

  const {
    data: votes,
    isLoading: isLoadingVotes,
    error: votesError,
    refetch: refetchVotes,
  } = useReadContract({
    address: arxAddress,
    abi: ARX_ABI,
    functionName: "getVotes",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address && !!arxAddress,
    },
  });

  const {
    data: governorVotes,
    isLoading: isLoadingGovernorVotes,
    error: governorVotesError,
  } = useReadContract({
    address: governorAddress,
    abi: GOVERNOR_ABI,
    functionName: "getVotes",
    args: [address!, blockNumber ? blockNumber - BigInt(1) : BigInt(0)],
    query: {
      enabled: !!address && !!governorAddress && !!blockNumber,
    },
  });

  const formattedVotes = useMemo(() => {
    if (!votes) return "0";
    return formatUnits(votes, 6);
  }, [votes]);

  const formattedGovernorVotes = useMemo(() => {
    if (!governorVotes) return "0";
    return formatUnits(governorVotes, 6);
  }, [governorVotes]);

  return {
    votes: votes ?? BigInt(0),
    formattedVotes,
    governorVotes: governorVotes ?? BigInt(0),
    formattedGovernorVotes,
    blockNumber,
    isLoading: isLoadingVotes || isLoadingGovernorVotes,
    error: votesError || governorVotesError,
    refetch: () => {
      refetchVotes();
      refetchBlockNumber();
    },
  };
};
