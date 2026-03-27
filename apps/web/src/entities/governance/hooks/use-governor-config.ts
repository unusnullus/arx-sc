"use client";

import { useMemo } from "react";
import { useAccount, useReadContracts } from "wagmi";

import { addressesByChain, FALLBACK_CHAIN_ID } from "@arx/config";
import { GOVERNOR_ABI } from "@arx/abi";
import { GovernorConfig } from "../types";

export const useGovernorConfig = () => {
  const { chainId } = useAccount();
  const currentChainId = chainId ?? FALLBACK_CHAIN_ID;
  const governorAddress = addressesByChain[currentChainId]?.ARX_GOVERNOR;

  const { data, isLoading, error, refetch } = useReadContracts({
    contracts: [
      {
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "proposalThreshold",
      },
      {
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "votingDelay",
      },
      {
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "votingPeriod",
      },
      {
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "quorumNumerator",
      },
      {
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "quorumDenominator",
      },
    ],
    query: {
      enabled: !!governorAddress,
    },
  });

  const config: GovernorConfig | undefined = useMemo(() => {
    if (!data || data.some((result) => result.status !== "success")) {
      return undefined;
    }

    return {
      proposalThreshold: (data[0]?.result as bigint) ?? BigInt(0),
      votingDelay: (data[1]?.result as bigint) ?? BigInt(0),
      votingPeriod: (data[2]?.result as bigint) ?? BigInt(0),
      quorumNumerator: (data[3]?.result as bigint) ?? BigInt(0),
      quorumDenominator: (data[4]?.result as bigint) ?? BigInt(0),
    };
  }, [data]);

  return {
    config,
    isLoading,
    error,
    refetch,
    governorAddress,
  };
};
