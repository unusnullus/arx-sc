"use client";

import { useCallback, useState, useMemo } from "react";

import {
  useAccount,
  useChainId,
  usePublicClient,
  useWalletClient,
  useSwitchChain,
} from "wagmi";
import { toast } from "@arx/ui/components";
import { parseUnits } from "viem";

import { addressesByChain, FALLBACK_CHAIN_ID } from "@arx/config";
import { ARX_TOKEN_SALE_ABI, ERC20_ABI } from "@arx/abi";

export interface BuyWithUSDCParams {
  amount: string;
}

export const useBuyWithUSDC = () => {
  const { address } = useAccount();
  const currentChainId = useChainId();
  const targetChainId = useMemo(
    () => Number(process.env.NEXT_PUBLIC_CHAIN_ID || FALLBACK_CHAIN_ID),
    [],
  );
  const publicClient = usePublicClient({ chainId: targetChainId });
  const { data: wallet } = useWalletClient();
  const { switchChain } = useSwitchChain();
  const [isLoading, setIsLoading] = useState(false);

  const cfg = useMemo(
    () => addressesByChain[targetChainId] || {},
    [targetChainId],
  );

  const ensureChain = useCallback(async () => {
    if (currentChainId !== targetChainId && switchChain) {
      try {
        await switchChain({ chainId: targetChainId });
      } catch (error) {
        console.error("Failed to switch chain:", error);
        throw error;
      }
    }
  }, [currentChainId, targetChainId, switchChain]);

  const buyWithUSDC = useCallback(
    async ({ amount }: BuyWithUSDCParams) => {
      if (!wallet || !publicClient || !address) {
        toast.error("Wallet not connected");
        return;
      }

      await ensureChain();

      const sale = cfg.ARX_TOKEN_SALE as `0x${string}` | undefined;
      const usdc = cfg.USDC as `0x${string}` | undefined;

      if (!sale || !usdc) {
        toast.error("Required contracts not configured");
        return;
      }

      try {
        setIsLoading(true);

        const amountWei = parseUnits(amount, 6);

        const allowance = (await publicClient.readContract({
          address: usdc,
          abi: ERC20_ABI,
          functionName: "allowance",
          args: [address, sale],
        })) as bigint;

        if (allowance < amountWei) {
          await wallet.writeContract({
            address: usdc,
            abi: ERC20_ABI,
            functionName: "approve",
            args: [sale, amountWei],
          });
          toast.success("Approval submitted");
        }

        await wallet.writeContract({
          address: sale,
          abi: ARX_TOKEN_SALE_ABI,
          functionName: "buyWithUSDC",
          args: [amountWei],
        });

        toast.success("Purchase submitted");
      } catch (error) {
        const errorMessage =
          error instanceof Error ? error.message : "Transaction failed";
        console.error("BuyWithUSDC error:", error);
        toast.error(errorMessage);
        throw error;
      } finally {
        setIsLoading(false);
      }
    },
    [wallet, publicClient, address, ensureChain, cfg],
  );

  return {
    buyWithUSDC,
    isLoading,
  };
};
