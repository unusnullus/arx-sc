"use client";

import { useCallback, useEffect, useState } from "react";
import {
  useAccount,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { toast } from "@arx/ui/components";

import { addressesByChain, FALLBACK_CHAIN_ID } from "@arx/config";
import { ARX_ABI } from "@arx/abi";

export const useDelegation = () => {
  const { address, chainId } = useAccount();
  const currentChainId = chainId ?? FALLBACK_CHAIN_ID;
  const arxAddress = addressesByChain[currentChainId]?.ARX;

  const [isDelegating, setIsDelegating] = useState(false);

  const {
    data: delegatee,
    isLoading: isLoadingDelegatee,
    error: delegateeError,
    refetch: refetchDelegatee,
  } = useReadContract({
    address: arxAddress,
    abi: ARX_ABI,
    functionName: "delegates",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address && !!arxAddress,
    },
  });

  const { writeContract, data: hash, isPending } = useWriteContract();

  const { isLoading: isConfirming, isSuccess: isConfirmed } =
    useWaitForTransactionReceipt({
      hash,
    });

  const isDelegated = useCallback(() => {
    if (!address || !delegatee) return false;
    return delegatee.toLowerCase() === address.toLowerCase();
  }, [address, delegatee]);

  const delegate = useCallback(
    async (delegateeAddress: `0x${string}`) => {
      if (!arxAddress || !address) {
        toast.error("Wallet not connected or ARX contract not configured");
        return;
      }

      if (!delegateeAddress || delegateeAddress === "0x") {
        toast.error("Invalid delegatee address");
        return;
      }

      try {
        setIsDelegating(true);

        await writeContract({
          address: arxAddress,
          abi: ARX_ABI,
          functionName: "delegate",
          args: [delegateeAddress],
        });

        toast.success("Delegation transaction submitted");
      } catch (error) {
        const errorMessage =
          error instanceof Error ? error.message : "Delegation failed";
        console.error("Delegate error:", error);
        toast.error(errorMessage);
        throw error;
      } finally {
        setIsDelegating(false);
      }
    },
    [arxAddress, address, writeContract],
  );

  const delegateToSelf = useCallback(() => {
    if (!address) {
      toast.error("Wallet not connected");
      return;
    }
    return delegate(address);
  }, [address, delegate]);

  useEffect(() => {
    if (isConfirmed) {
      refetchDelegatee();
    }
  }, [isConfirmed, refetchDelegatee]);

  return {
    delegatee: delegatee as `0x${string}` | undefined,
    isDelegated: isDelegated(),
    isLoading: isLoadingDelegatee,
    error: delegateeError,
    delegate,
    delegateToSelf,
    isDelegating: isDelegating || isPending || isConfirming,
    isConfirmed,
    hash,
    refetch: refetchDelegatee,
  };
};
