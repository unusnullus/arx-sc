"use client";

import { useCallback, useEffect, useMemo } from "react";

import { toast } from "@arx/ui/components";
import { useAccount, useSwitchChain } from "wagmi";
import { MAINNET_CHAINS, TESTNET_CHAINS } from "../constants";
import { ChainConfig } from "../types";

export const useChain = (
  options: {
    showTestnets?: boolean;
    onChainChange?: (chainId: number) => void;
  } = {},
) => {
  const { onChainChange } = options;

  const { chainId } = useAccount();
  const {
    switchChain: wagmiSwitchChain,
    isPending,
    chains,
    error,
    isSuccess,
  } = useSwitchChain();
  const { isConnected } = useAccount();

  const currentChain = useMemo(() => {
    if (!chainId) return null;
    return (
      [...MAINNET_CHAINS, ...TESTNET_CHAINS].find(
        (chain) => chain.id === chainId,
      ) || null
    );
  }, [chainId]);

  const isUnsupportedChain = useMemo(() => {
    return !!chainId && !currentChain;
  }, [chainId, currentChain]);

  const availableChains = useMemo(() => {
    const filteredChains = [...MAINNET_CHAINS, ...TESTNET_CHAINS];

    return filteredChains.filter((chain) =>
      chains.some((wagmiChain) => wagmiChain.id === chain.id),
    );
  }, [chains]);

  const switchChain = useCallback(
    async (targetChainId: number) => {
      if (!wagmiSwitchChain || !isConnected) {
        toast.error("Wallet not connected or chain switching not available");
        return;
      }

      const targetChain = [...MAINNET_CHAINS, ...TESTNET_CHAINS].find(
        (chain) => chain.id === targetChainId,
      );

      if (!targetChain) {
        toast.error("Unsupported chain");
        return;
      }

      if (targetChainId === chainId) {
        toast.info(`Already connected to ${targetChain.name}`);
        return;
      }

      try {
        await wagmiSwitchChain({ chainId: targetChainId });
        onChainChange?.(targetChainId);
      } catch (error) {
        if (error instanceof Error) {
          if (error.message.includes("User rejected")) {
            toast.error("Chain switch was cancelled");
          } else if (error.message.includes("Unsupported chain")) {
            toast.error("This chain is not supported by your wallet");
          } else {
            toast.error("Failed to switch chain");
          }
        } else {
          toast.error("Failed to switch chain");
        }
      }
    },
    [wagmiSwitchChain, isConnected, chainId, onChainChange],
  );

  useEffect(() => {
    if (isSuccess && currentChain) {
      toast.success(`Switched to ${currentChain?.name}`);
    }
  }, [isSuccess, currentChain]);

  useEffect(() => {
    if (error) {
      if (error.message.includes("User rejected")) {
        toast.error("Chain switch was cancelled");
      } else if (error.message.includes("Unsupported chain")) {
        toast.error("This chain is not supported by your wallet");
      } else {
        toast.error("Failed to switch chain");
      }
    }
  }, [error]);

  const getChainById = useCallback((id: number): ChainConfig | null => {
    return (
      [...MAINNET_CHAINS, ...TESTNET_CHAINS].find((chain) => chain.id === id) ||
      null
    );
  }, []);

  const isChainSupported = useCallback((id: number): boolean => {
    return [...MAINNET_CHAINS, ...TESTNET_CHAINS].some(
      (chain) => chain.id === id,
    );
  }, []);

  const isTestnet = useCallback(
    (chainId: number): boolean => {
      const chain = getChainById(chainId);
      return chain?.testnet || false;
    },
    [getChainById],
  );

  return {
    chainId,
    currentChain,
    isConnected,
    isUnsupportedChain,

    availableChains,
    mainnetChains: MAINNET_CHAINS,
    testnetChains: TESTNET_CHAINS,

    switchChain,
    isSwitching: isPending,

    getChainById,
    isChainSupported,
    isTestnet,
  };
};
