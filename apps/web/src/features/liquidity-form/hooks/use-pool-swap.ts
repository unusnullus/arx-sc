"use client";

import { useCallback } from "react";

import { Address, parseUnits } from "viem";
import { useAccount, usePublicClient, useWriteContract } from "wagmi";

import { FALLBACK_CHAIN_ID, Token, addressesByChain } from "@arx/config";
import { ARX_ABI, RATE_POOL_ABI, ERC20_ABI } from "@arx/abi";
import { toast } from "@arx/ui/components";
import { useQueryClient } from "@tanstack/react-query";

interface UsePoolSwapParams {
  fromToken: Token;
  toToken: Token;
  usdcToken: Token;
  isFromUSDC: boolean;
  fromAmount: string;
  chainId?: number;
  onSuccess?: () => void;
}

export const usePoolSwap = ({
  fromToken,
  usdcToken,
  isFromUSDC,
  fromAmount,
  chainId,
  onSuccess,
}: UsePoolSwapParams) => {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const queryClient = useQueryClient();
  const { writeContractAsync } = useWriteContract();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;

  const ratePoolAddress = addressesByChain[targetChainId]?.RATE_POOL;
  const arxAddress = addressesByChain[targetChainId]?.ARX;

  const approveIfNeeded = useCallback(
    async (token: Token, spender: Address, need: bigint) => {
      if (!address || !publicClient) return;
      const allowance = await publicClient
        .readContract({
          address: token.address as Address,
          abi: ERC20_ABI,
          functionName: "allowance",
          args: [address as Address, spender],
        })
        .catch(() => 0 as const);

      const current = (allowance as bigint | undefined) ?? 0;
      if (current >= need) return;

      const hash = await writeContractAsync({
        address: token.address as Address,
        abi: ERC20_ABI,
        functionName: "approve",
        args: [spender, need],
      });
      await publicClient.waitForTransactionReceipt({ hash });
    },
    [address, publicClient, writeContractAsync],
  );

  const handleSwap = useCallback(async () => {
    if (!fromAmount || Number(fromAmount) <= 0) {
      toast.error("Invalid amount");
      return;
    }
    if (!address) {
      toast.error("Wallet not connected");
      return;
    }
    if (!ratePoolAddress) {
      toast.error("Unsupported network");
      return;
    }
    if (!arxAddress) {
      toast.error("Unsupported network");
      return;
    }
    if (!publicClient) {
      toast.error("Unsupported network");
      return;
    }

    try {
      const amountWei = parseUnits(fromAmount, fromToken.decimals);

      const balance = (await publicClient.readContract({
        address: fromToken.address as Address,
        abi: ERC20_ABI,
        functionName: "balanceOf",
        args: [address as Address],
      })) as unknown as bigint;
      if ((balance ?? BigInt(0)) < amountWei) {
        toast.error("Insufficient balance");
        return;
      }

      const feeRaw = (await publicClient.readContract({
        address: ratePoolAddress as Address,
        abi: RATE_POOL_ABI,
        functionName: "swapFee",
      })) as unknown as bigint;
      const BASIS = BigInt(10000);
      const SLIPPAGE_BPS = BigInt(9950);

      const feeBpsOnchain = BigInt(feeRaw);
      const amountInAfterFee = (amountWei * (BASIS - feeBpsOnchain)) / BASIS;

      const expectedOut = (await (isFromUSDC
        ? publicClient.readContract({
            address: arxAddress as Address,
            abi: ARX_ABI,
            functionName: "getTokenToArxExchangeRate",
            args: [usdcToken.address as Address, amountInAfterFee],
          })
        : publicClient.readContract({
            address: arxAddress as Address,
            abi: ARX_ABI,
            functionName: "getArxPriceInToken",
            args: [usdcToken.address as Address, amountInAfterFee],
          }))) as unknown as bigint;
      const minOut = (expectedOut * SLIPPAGE_BPS) / BASIS;

      if (minOut <= BigInt(0)) {
        toast.error("Calculated minOut is zero");
        return;
      }

      await approveIfNeeded(fromToken, ratePoolAddress as Address, amountWei);

      const fn = isFromUSDC ? "swapExactUSDCToARX" : "swapExactARXToUSDC";
      const args = [amountWei, minOut] as readonly [bigint, bigint];

      const tx = await writeContractAsync({
        address: ratePoolAddress as Address,
        abi: RATE_POOL_ABI,
        functionName: fn,
        args,
      });
      toast.info("Transaction sent");
      await publicClient.waitForTransactionReceipt({ hash: tx });
      toast.success("Transaction sent");
      onSuccess?.();

      queryClient.invalidateQueries({
        queryKey: [
          "readContract",
          {
            functionName: "balanceOf",
          },
        ],
      });
    } catch (error) {
      console.error("Swap failed:", error);
      toast.error("Transaction failed");
    }
  }, [
    address,
    approveIfNeeded,
    fromAmount,
    fromToken,
    isFromUSDC,
    publicClient,
    ratePoolAddress,
    usdcToken.address,
    arxAddress,
    writeContractAsync,
    onSuccess,
    queryClient,
  ]);

  return {
    handleSwap,
  };
};
