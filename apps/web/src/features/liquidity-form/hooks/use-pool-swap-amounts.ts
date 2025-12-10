"use client";

import { useCallback, useEffect, useState } from "react";

import { Address, formatUnits, parseUnits } from "viem";
import { usePublicClient, useReadContract } from "wagmi";

import { FALLBACK_CHAIN_ID, Token, addressesByChain } from "@arx/config";
import { ARX_ABI, RATE_POOL_ABI } from "@arx/abi";

interface UsePoolSwapAmountsParams {
  fromToken: Token;
  toToken: Token;
  usdcToken: Token;
  isFromUSDC: boolean;
  chainId?: number;
}

export const usePoolSwapAmounts = ({
  fromToken,
  toToken,
  usdcToken,
  isFromUSDC,
  chainId,
}: UsePoolSwapAmountsParams) => {
  const publicClient = usePublicClient();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;
  const [fromAmount, setFromAmount] = useState<string>("");
  const [toAmount, setToAmount] = useState<string>("");

  const ratePoolAddress = addressesByChain[targetChainId]?.RATE_POOL;
  const arxAddress = addressesByChain[targetChainId]?.ARX;

  const { data: swapFeeBps } = useReadContract({
    address: ratePoolAddress as `0x${string}`,
    abi: RATE_POOL_ABI,
    functionName: "swapFee",
    query: { enabled: !!ratePoolAddress },
  });

  const feeBps = Number((swapFeeBps as number | bigint | undefined) ?? 0);
  const feeFactor = Math.max(0, 1 - feeBps / 10000);

  useEffect(() => {
    if (!fromAmount) {
      setToAmount("");
      return;
    }
    if (!publicClient || !arxAddress || !ratePoolAddress) return;

    const calculateToAmount = async () => {
      try {
        const BASIS = BigInt(10000);
        const amountInWei = parseUnits(fromAmount, fromToken.decimals);
        if (amountInWei <= BigInt(0)) {
          setToAmount("");
          return;
        }

        const fee = BigInt(
          Number((swapFeeBps as bigint | number | undefined) ?? 0),
        );
        const amountInAfterFee = (amountInWei * (BASIS - fee)) / BASIS;

        const promise = isFromUSDC
          ? (publicClient.readContract({
              address: arxAddress as Address,
              abi: ARX_ABI,
              functionName: "getTokenToArxExchangeRate",
              args: [usdcToken.address as Address, amountInAfterFee],
            }) as unknown as Promise<bigint>)
          : (publicClient.readContract({
              address: arxAddress as Address,
              abi: ARX_ABI,
              functionName: "getArxPriceInToken",
              args: [usdcToken.address as Address, amountInAfterFee],
            }) as unknown as Promise<bigint>);

        const out = await promise;
        const formatted = Number(formatUnits(out, toToken.decimals));
        setToAmount(
          Number.isFinite(formatted) && formatted > 0
            ? formatted.toFixed(6)
            : "",
        );
      } catch {}
    };

    void calculateToAmount();
  }, [
    fromAmount,
    fromToken.decimals,
    toToken.decimals,
    feeBps,
    isFromUSDC,
    publicClient,
    arxAddress,
    usdcToken.address,
    ratePoolAddress,
    swapFeeBps,
  ]);

  const handleFromAmountChange = useCallback((value: string) => {
    setFromAmount(value);
  }, []);

  const handleToAmountChange = useCallback(
    (value: string) => {
      setToAmount(value);
      if (!value) {
        setFromAmount("");
        return;
      }
      const v = Number(value);
      if (Number.isNaN(v) || feeFactor === 0) return;
      const back = v / feeFactor;
      setFromAmount(back.toFixed(6));
    },
    [feeFactor],
  );

  const resetAmounts = useCallback(() => {
    setFromAmount("");
    setToAmount("");
  }, []);

  return {
    fromAmount,
    toAmount,
    handleFromAmountChange,
    handleToAmountChange,
    resetAmounts,
    setFromAmount,
    setToAmount,
  };
};
