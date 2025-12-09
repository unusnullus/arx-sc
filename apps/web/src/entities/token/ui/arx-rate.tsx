"use client";

import { memo } from "react";

import { AlertCircle } from "lucide-react";
import { formatUnits, parseUnits } from "viem";
import { useAccount, useReadContract } from "wagmi";

import {
  FALLBACK_CHAIN_ID,
  Token,
  ZERO_ADDRESS,
  addressesByChain,
  isNativeToken,
} from "@arx/config";
import { Spinner } from "@arx/ui/components";
import { ARX_ABI } from "@arx/abi";

const ArxRateBase = ({ token, amount }: { token: Token; amount: string }) => {
  const { chainId } = useAccount();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;
  const arxAddress = addressesByChain[targetChainId]?.ARX;

  const tokenAddress = isNativeToken(token.address)
    ? ZERO_ADDRESS
    : token.address;

  const enabled =
    !!arxAddress && !!token.address && !!amount && Number(amount) > 0;

  const {
    data: arxRate,
    isLoading,
    isError,
  } = useReadContract({
    address: arxAddress!,
    abi: ARX_ABI,
    functionName: "getTokenToArxExchangeRate",
    args: [tokenAddress, parseUnits(amount, token.decimals)],
    query: {
      enabled,
    },
  });

  if (isLoading) {
    return (
      <span className="text-content-70 flex items-center justify-end text-lg">
        <Spinner variant="ellipsis" />
      </span>
    );
  }

  if (isError) {
    return (
      <span className="text-error flex items-center justify-end gap-1 text-lg">
        <AlertCircle className="h-4 w-4" /> Error fetching price
      </span>
    );
  }

  return (
    <span className="text-content-70 text-lg">
      ~{formatUnits(arxRate ?? BigInt(0), 6)}
    </span>
  );
};

export const ArxRate = memo(ArxRateBase);
