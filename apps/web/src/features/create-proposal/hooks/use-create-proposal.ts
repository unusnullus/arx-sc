"use client";

import { useCallback } from "react";
import {
  useAccount,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { toast } from "@arx/ui/components";

import { addressesByChain, FALLBACK_CHAIN_ID } from "@arx/config";
import { GOVERNOR_ABI } from "@arx/abi";

export interface CreateProposalParams {
  targets: `0x${string}`[];
  values: bigint[];
  calldatas: `0x${string}`[];
  description: string;
}

export const useCreateProposal = () => {
  const { address, chainId } = useAccount();
  const currentChainId = chainId ?? FALLBACK_CHAIN_ID;
  const governorAddress = addressesByChain[currentChainId]?.ARX_GOVERNOR;

  const { writeContract, data: hash } = useWriteContract();

  const { isLoading: isConfirming, isSuccess: isConfirmed } =
    useWaitForTransactionReceipt({
      hash,
    });

  const createProposal = useCallback(
    async ({
      targets,
      values,
      calldatas,
      description,
    }: CreateProposalParams) => {
      if (!governorAddress || !address) {
        toast.error("Wallet not connected or Governor contract not configured");
        return;
      }

      if (targets.length === 0) {
        toast.error("At least one target is required");
        return;
      }

      if (
        targets.length !== values.length ||
        targets.length !== calldatas.length
      ) {
        toast.error(
          "Targets, values, and calldatas arrays must have the same length",
        );
        return;
      }

      try {
        await writeContract({
          address: governorAddress,
          abi: GOVERNOR_ABI,
          functionName: "propose",
          args: [targets, values, calldatas, description],
        });

        toast.success("Proposal creation transaction submitted");
      } catch (error) {
        const errorMessage =
          error instanceof Error ? error.message : "Proposal creation failed";
        console.error("Create proposal error:", error);

        if (errorMessage.includes("GovernorInsufficientProposerVotes")) {
          toast.error("Insufficient voting power to create proposal");
        } else if (errorMessage.includes("GovernorInvalidProposalLength")) {
          toast.error("Invalid proposal parameters");
        } else {
          toast.error(errorMessage);
        }
        throw error;
      }
    },
    [governorAddress, address, writeContract],
  );

  return {
    createProposal,
    isCreating: isConfirming,
    isConfirmed,
    hash,
  };
};
