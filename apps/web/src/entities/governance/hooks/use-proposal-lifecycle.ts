"use client";

import { useCallback, useState } from "react";
import {
  useAccount,
  useWriteContract,
  useWaitForTransactionReceipt,
  useReadContract,
} from "wagmi";
import { toast } from "@arx/ui/components";
import { keccak256, toBytes } from "viem";

import { addressesByChain, FALLBACK_CHAIN_ID } from "@arx/config";
import { GOVERNOR_ABI } from "@arx/abi";
import { Proposal } from "../types";

export const useProposalLifecycle = (proposal: Proposal | undefined) => {
  const { address, chainId } = useAccount();
  const currentChainId = chainId ?? FALLBACK_CHAIN_ID;
  const governorAddress = addressesByChain[currentChainId]?.ARX_GOVERNOR;

  const [isProcessing, setIsProcessing] = useState(false);

  const { writeContract, data: hash, isPending } = useWriteContract();

  const { isLoading: isConfirming, isSuccess: isConfirmed } =
    useWaitForTransactionReceipt({
      hash,
    });

  const { data: proposer } = useReadContract({
    address: governorAddress,
    abi: GOVERNOR_ABI,
    functionName: "proposalProposer",
    args: proposal ? [proposal.id] : undefined,
    query: {
      enabled: !!proposal && !!governorAddress,
    },
  });

  const { data: needsQueuing } = useReadContract({
    address: governorAddress,
    abi: GOVERNOR_ABI,
    functionName: "proposalNeedsQueuing",
    args: proposal ? [proposal.id] : undefined,
    query: {
      enabled: !!proposal && !!governorAddress,
    },
  });

  const isProposer =
    !!address &&
    !!proposer &&
    address.toLowerCase() === (proposer as string).toLowerCase();

  const queue = useCallback(async () => {
    if (!governorAddress || !address || !proposal) {
      toast.error("Wallet not connected or proposal not available");
      return;
    }

    try {
      setIsProcessing(true);

      const descriptionHash = keccak256(toBytes(proposal.description));

      await writeContract({
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "queue",
        args: [
          proposal.targets,
          proposal.values,
          proposal.calldatas,
          descriptionHash,
        ],
      });

      toast.success("Proposal queued successfully");
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : "Queue failed";
      console.error("Queue error:", error);

      if (errorMessage.includes("GovernorUnexpectedProposalState")) {
        toast.error("Proposal is not in the correct state to be queued");
      } else if (errorMessage.includes("GovernorOnlyExecutor")) {
        toast.error("Only executor can queue proposals");
      } else {
        toast.error(errorMessage);
      }
      throw error;
    } finally {
      setIsProcessing(false);
    }
  }, [governorAddress, address, proposal, writeContract]);

  const execute = useCallback(async () => {
    if (!governorAddress || !address || !proposal) {
      toast.error("Wallet not connected or proposal not available");
      return;
    }

    try {
      setIsProcessing(true);

      const descriptionHash = keccak256(toBytes(proposal.description));

      await writeContract({
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "execute",
        args: [
          proposal.targets,
          proposal.values,
          proposal.calldatas,
          descriptionHash,
        ],
      });

      toast.success("Proposal executed successfully");
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : "Execute failed";
      console.error("Execute error:", error);

      if (errorMessage.includes("GovernorUnexpectedProposalState")) {
        toast.error("Proposal is not in the correct state to be executed");
      } else if (errorMessage.includes("GovernorOnlyExecutor")) {
        toast.error("Only executor can execute proposals");
      } else {
        toast.error(errorMessage);
      }
      throw error;
    } finally {
      setIsProcessing(false);
    }
  }, [governorAddress, address, proposal, writeContract]);

  const cancel = useCallback(async () => {
    if (!governorAddress || !address || !proposal) {
      toast.error("Wallet not connected or proposal not available");
      return;
    }

    if (!isProposer) {
      toast.error("Only the proposer can cancel this proposal");
      return;
    }

    try {
      setIsProcessing(true);

      const descriptionHash = keccak256(toBytes(proposal.description));

      await writeContract({
        address: governorAddress,
        abi: GOVERNOR_ABI,
        functionName: "cancel",
        args: [
          proposal.targets,
          proposal.values,
          proposal.calldatas,
          descriptionHash,
        ],
      });

      toast.success("Proposal canceled successfully");
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : "Cancel failed";
      console.error("Cancel error:", error);

      if (errorMessage.includes("GovernorUnableToCancel")) {
        toast.error("Unable to cancel this proposal");
      } else {
        toast.error(errorMessage);
      }
      throw error;
    } finally {
      setIsProcessing(false);
    }
  }, [governorAddress, address, proposal, isProposer, writeContract]);

  return {
    queue,
    execute,
    cancel,
    isProposer: !!isProposer,
    needsQueuing: needsQueuing ?? false,
    isProcessing: isProcessing || isPending || isConfirming,
    isConfirmed,
    hash,
  };
};
