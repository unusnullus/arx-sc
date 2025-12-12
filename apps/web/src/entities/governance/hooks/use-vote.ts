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
import { GOVERNOR_ABI } from "@arx/abi";
import { VoteType } from "../types";

export const useVote = (proposalId: bigint) => {
  const { address, chainId } = useAccount();
  const currentChainId = chainId ?? FALLBACK_CHAIN_ID;
  const governorAddress = addressesByChain[currentChainId]?.ARX_GOVERNOR;

  const [isVoting, setIsVoting] = useState(false);

  const {
    data: voteReceipt,
    isLoading: isLoadingHasVoted,
    refetch: refetchHasVoted,
  } = useReadContract({
    address: governorAddress,
    abi: GOVERNOR_ABI,
    functionName: "getVoteReceipt",
    args: address && proposalId ? [proposalId, address] : undefined,
    query: {
      enabled: !!address && !!governorAddress && !!proposalId,
    },
  });

  const hasVoted = voteReceipt?.hasVoted;
  const voteSupport = voteReceipt?.support as VoteType | undefined;
  const voteWeight = voteReceipt?.votes as bigint | undefined;

  const { writeContract, data: hash, isPending } = useWriteContract();

  const { isLoading: isConfirming, isSuccess: isConfirmed } =
    useWaitForTransactionReceipt({
      hash,
    });

  const castVote = useCallback(
    async (support: VoteType, reason?: string) => {
      if (!governorAddress || !address) {
        toast.error("Wallet not connected or Governor contract not configured");
        return;
      }

      if (hasVoted) {
        toast.error("You have already voted on this proposal");
        return;
      }

      try {
        setIsVoting(true);

        if (reason && reason.trim()) {
          await writeContract({
            address: governorAddress,
            abi: GOVERNOR_ABI,
            functionName: "castVoteWithReason",
            args: [proposalId, support, reason],
          });
        } else {
          await writeContract({
            address: governorAddress,
            abi: GOVERNOR_ABI,
            functionName: "castVote",
            args: [proposalId, support],
          });
        }

        toast.success("Vote submitted successfully");
      } catch (error) {
        const errorMessage =
          error instanceof Error ? error.message : "Vote failed";
        console.error("Cast vote error:", error);

        if (errorMessage.includes("GovernorAlreadyCastVote")) {
          toast.error("You have already voted on this proposal");
        } else {
          toast.error(errorMessage);
        }
        throw error;
      } finally {
        setIsVoting(false);
      }
    },
    [governorAddress, address, proposalId, hasVoted, writeContract],
  );

  useEffect(() => {
    if (isConfirmed) {
      refetchHasVoted();
    }
  }, [isConfirmed, refetchHasVoted]);

  return {
    hasVoted: hasVoted as boolean | undefined,
    voteSupport,
    voteWeight,
    isLoadingHasVoted,
    castVote,
    isVoting: isVoting || isPending || isConfirming,
    isConfirmed,
    hash,
  };
};
