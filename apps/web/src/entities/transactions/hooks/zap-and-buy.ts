"use client";

import { useCallback, useState, useMemo } from "react";

import { encodePacked } from "viem";
import {
  useAccount,
  useChainId,
  usePublicClient,
  useWalletClient,
  useSwitchChain,
} from "wagmi";
import { toast } from "@arx/ui/components";
import { parseUnits } from "viem";

import {
  Token,
  isNativeToken,
  addressesByChain,
  constants,
  FALLBACK_CHAIN_ID,
} from "@arx/config";
import { ARX_ZAPPER_ABI, ERC20_ABI } from "@arx/abi";
import { PermitParams } from "@/entities/permit/types";

export interface ZapAndBuyParams {
  token?: Token | null;
  amount: string;
  slippageBps?: bigint;
  deadlineMinutes?: number;
  quoteUsdcOut?: bigint | null;
}

export interface ZapAndBuyWithPermitParams extends ZapAndBuyParams {
  permitParams: PermitParams;
}

export const useZapAndBuy = () => {
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

  const calculateMinUsdcOut = useCallback(
    (quoted: bigint, slippageBps: bigint): bigint => {
      if (quoted === BigInt(0)) return BigInt(0);
      return (quoted * BigInt(10000 - Number(slippageBps))) / BigInt(10000);
    },
    [],
  );

  const buildPath = useCallback(
    (
      tokenIn: `0x${string}`,
      tokenOut: `0x${string}`,
      fee: number = 500,
    ): `0x${string}` => {
      return encodePacked(
        ["address", "uint24", "address"],
        [tokenIn, fee, tokenOut],
      ) as `0x${string}`;
    },
    [],
  );

  const approveIfNeeded = useCallback(
    async (token: Token, spender: `0x${string}`, amount: bigint) => {
      if (!publicClient || !wallet || !address) return;

      try {
        const allowance = (await publicClient
          .readContract({
            address: token.address as `0x${string}`,
            abi: ERC20_ABI,
            functionName: "allowance",
            args: [address, spender],
          })
          .catch(() => BigInt(0))) as bigint;

        if (allowance >= amount) return;

        const hash = await wallet.writeContract({
          address: token.address as `0x${string}`,
          abi: ERC20_ABI,
          functionName: "approve",
          args: [spender, amount],
        });

        await publicClient.waitForTransactionReceipt({ hash });
      } catch (error) {
        console.error("Approve failed:", error);
        throw error;
      }
    },
    [publicClient, wallet, address],
  );

  const zapAndBuy = useCallback(
    async ({
      token,
      amount,
      slippageBps,
      deadlineMinutes,
      quoteUsdcOut,
    }: ZapAndBuyParams) => {
      if (!wallet || !publicClient || !address) {
        toast.error("Wallet not connected");
        return;
      }

      await ensureChain();

      const zap = cfg.ARX_ZAPPER as `0x${string}` | undefined;
      const usdc = cfg.USDC as `0x${string}` | undefined;
      const weth9 = cfg.WETH9 as `0x${string}` | undefined;

      if (!zap || !usdc || !weth9) {
        toast.error("Required contracts not configured");
        return;
      }

      try {
        setIsLoading(true);

        const deadline = BigInt(
          Math.floor(Date.now() / 1000) +
            (deadlineMinutes ?? constants.defaultDeadlineMinutes) * 60,
        );

        const effectiveSlippageBps =
          slippageBps ?? BigInt(constants.defaultSlippageBps);
        const minUsdcOut = quoteUsdcOut
          ? calculateMinUsdcOut(quoteUsdcOut, effectiveSlippageBps)
          : BigInt(0);

        const amountWei = parseUnits(amount, token?.decimals ?? 0);
        let tokenIn: `0x${string}`;
        let path: `0x${string}`;

        if (isNativeToken(token?.address)) {
          tokenIn =
            "0x0000000000000000000000000000000000000000" as `0x${string}`;
          path = buildPath(weth9, usdc);
        } else {
          tokenIn = token?.address as `0x${string}`;
          path = buildPath(tokenIn, usdc);

          if (token) {
            await approveIfNeeded(token, zap, amountWei);
          }
        }

        await wallet.writeContract({
          address: zap,
          abi: ARX_ZAPPER_ABI,
          functionName: "zapAndBuy",
          args: [tokenIn, amountWei, path, minUsdcOut, address, deadline],
          ...(isNativeToken(token?.address) && { value: amountWei }),
        });

        toast.success("Zap and buy submitted");
      } catch (error) {
        const errorMessage =
          error instanceof Error ? error.message : "Transaction failed";
        console.error("ZapAndBuy error:", error);
        toast.error(errorMessage);
        throw error;
      } finally {
        setIsLoading(false);
      }
    },
    [
      wallet,
      publicClient,
      address,
      ensureChain,
      cfg,
      calculateMinUsdcOut,
      buildPath,
      approveIfNeeded,
    ],
  );

  const zapAndBuyWithPermit = useCallback(
    async ({
      token,
      amount,
      permitParams,
      slippageBps,
      deadlineMinutes,
      quoteUsdcOut,
    }: ZapAndBuyWithPermitParams) => {
      if (!wallet || !publicClient || !address) {
        toast.error("Wallet not connected");
        return;
      }

      if (isNativeToken(token?.address)) {
        toast.error("Permit not supported for native tokens");
        return;
      }

      await ensureChain();

      const zap = cfg.ARX_ZAPPER as `0x${string}` | undefined;
      const usdc = cfg.USDC as `0x${string}` | undefined;

      if (!zap || !usdc) {
        toast.error("Required contracts not configured");
        return;
      }

      try {
        setIsLoading(true);

        const deadline = BigInt(
          Math.floor(Date.now() / 1000) +
            (deadlineMinutes ?? constants.defaultDeadlineMinutes) * 60,
        );

        const effectiveSlippageBps =
          slippageBps ?? BigInt(constants.defaultSlippageBps);
        const minUsdcOut = quoteUsdcOut
          ? calculateMinUsdcOut(quoteUsdcOut, effectiveSlippageBps)
          : BigInt(0);

        const tokenIn = token?.address as `0x${string}`;
        const amountWei = parseUnits(amount, token?.decimals ?? 0);
        const path = buildPath(tokenIn, usdc);

        await wallet.writeContract({
          address: zap,
          abi: ARX_ZAPPER_ABI,
          functionName: "zapAndBuyWithPermit",
          args: [
            tokenIn,
            amountWei,
            path,
            minUsdcOut,
            address,
            deadline,
            address, // owner
            permitParams.value,
            permitParams.deadline,
            permitParams.v,
            permitParams.r,
            permitParams.s,
          ],
        });

        toast.success("Zap and buy with permit submitted");
      } catch (error) {
        const errorMessage =
          error instanceof Error ? error.message : "Transaction failed";
        console.error("ZapAndBuyWithPermit error:", error);
        toast.error(errorMessage);
        throw error;
      } finally {
        setIsLoading(false);
      }
    },
    [
      wallet,
      publicClient,
      address,
      ensureChain,
      cfg,
      calculateMinUsdcOut,
      buildPath,
    ],
  );

  return {
    zapAndBuy,
    zapAndBuyWithPermit,
    isLoading,
  };
};
