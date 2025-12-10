"use client";

import { useEffect, useState } from "react";

import { Address, formatUnits, parseUnits } from "viem";
import { usePublicClient, useReadContract } from "wagmi";

import { FALLBACK_CHAIN_ID, Token, addressesByChain } from "@arx/config";
import { ARX_ABI, RATE_POOL_ABI } from "@arx/abi";

interface UsePoolSwapRateParams {
  fromToken: Token;
  toToken: Token;
  usdcToken: Token;
  isFromUSDC: boolean;
  chainId?: number;
}

export const usePoolSwapRate = ({
  fromToken,
  toToken,
  usdcToken,
  isFromUSDC,
  chainId,
}: UsePoolSwapRateParams) => {
  const publicClient = usePublicClient();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;
  const [rateText, setRateText] = useState<string>("");

  const ratePoolAddress = addressesByChain[targetChainId]?.RATE_POOL;
  const arxAddress = addressesByChain[targetChainId]?.ARX;

  const { data: swapFeeBps } = useReadContract({
    address: ratePoolAddress as `0x${string}`,
    abi: RATE_POOL_ABI,
    functionName: "swapFee",
    query: { enabled: !!ratePoolAddress },
  });

  useEffect(() => {
    if (!publicClient || !arxAddress || !ratePoolAddress) {
      setRateText("");
      return;
    }

    const fetchRate = async () => {
      try {
        const BASIS = BigInt(10000);
        const oneUnit = parseUnits("1", fromToken.decimals);
        const fee = BigInt(
          Number((swapFeeBps as bigint | number | undefined) ?? 0),
        );
        const amountInAfterFee = (oneUnit * (BASIS - fee)) / BASIS;

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
        setRateText(
          Number.isFinite(formatted) && formatted > 0
            ? formatted.toFixed(6)
            : "",
        );
      } catch {
        setRateText("");
      }
    };

    void fetchRate();
  }, [
    isFromUSDC,
    fromToken.decimals,
    toToken.decimals,
    swapFeeBps,
    publicClient,
    arxAddress,
    usdcToken.address,
    ratePoolAddress,
  ]);

  return rateText;
};
