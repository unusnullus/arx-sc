"use client";

import { memo, useMemo } from "react";

import Image from "next/image";

import { Address, formatUnits } from "viem";
import { useAccount, useReadContract } from "wagmi";

import {
  addressesByChain,
  FALLBACK_CHAIN_ID,
  getTokenBySymbolSafe,
} from "@arx/config";
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Separator,
} from "@arx/ui/components";
import { RATE_POOL_ABI } from "@arx/abi";
import { cn } from "@arx/ui/lib";

export const PoolBalanceWidget = memo(
  ({
    className,
    viewDetails = false,
  }: {
    className?: string;
    viewDetails?: boolean;
  }) => {
    const { address, chainId } = useAccount();
    const targetChainId = chainId ?? FALLBACK_CHAIN_ID;

    const ratePool = useMemo(
      () => addressesByChain[targetChainId]?.RATE_POOL,
      [targetChainId],
    );

    const usdc = useMemo(
      () => getTokenBySymbolSafe("USDC", targetChainId),
      [targetChainId],
    );
    const arx = useMemo(
      () => getTokenBySymbolSafe("ARX", targetChainId),
      [targetChainId],
    );

    const { data: reserves } = useReadContract({
      address: (ratePool ?? undefined) as Address | undefined,
      abi: RATE_POOL_ABI,
      functionName: "getReserves",
      query: { enabled: Boolean(ratePool), refetchInterval: 30000 },
    });

    const { data: lpDecimals } = useReadContract({
      address: (ratePool ?? undefined) as Address | undefined,
      abi: RATE_POOL_ABI,
      functionName: "decimals",
      query: { enabled: Boolean(ratePool), refetchInterval: 30000 },
    });

    const { data: totalSupply } = useReadContract({
      address: (ratePool ?? undefined) as Address | undefined,
      abi: RATE_POOL_ABI,
      functionName: "totalSupply",
      query: { enabled: Boolean(ratePool), refetchInterval: 30000 },
    });

    const { data: userLp } = useReadContract({
      address: (ratePool ?? undefined) as Address | undefined,
      abi: RATE_POOL_ABI,
      functionName: "balanceOf",
      args: [
        (address ?? "0x0000000000000000000000000000000000000000") as Address,
      ],
      query: { enabled: Boolean(ratePool && address), refetchInterval: 30000 },
    });

    const reserveARX = (reserves as readonly [bigint, bigint] | undefined)?.[0];
    const reserveUSDC = (
      reserves as readonly [bigint, bigint] | undefined
    )?.[1];

    const usdcText =
      usdc && reserveUSDC !== undefined
        ? Number(formatUnits(reserveUSDC, usdc.decimals)).toLocaleString()
        : "-";
    const arxText =
      arx && reserveARX !== undefined
        ? Number(formatUnits(reserveARX, arx.decimals)).toLocaleString()
        : "-";

    const totalLpNum =
      totalSupply !== undefined
        ? Number(formatUnits(totalSupply as bigint, lpDecimals as number))
        : null;
    const userLpNum =
      userLp !== undefined
        ? Number(formatUnits(userLp as bigint, lpDecimals as number))
        : null;

    const lpText =
      userLpNum !== null
        ? userLpNum === 0
          ? "0"
          : userLpNum < 0.000001
            ? "<0.000001"
            : userLpNum.toLocaleString(undefined, { maximumFractionDigits: 12 })
        : "-";

    const shareText =
      userLpNum !== null && totalLpNum !== null && totalLpNum > 0
        ? `${((userLpNum / totalLpNum) * 100).toFixed(2)}%`
        : "-";

    return (
      <Card className={cn("gap-0", className)}>
        <CardHeader className="pb-3">
          <CardTitle className="text-base-primary text-sm font-semibold">
            <div className="flex items-center justify-between">
              <h1 className="text-base-primary text-base font-semibold sm:text-lg lg:text-xl">
                Pool Balance
              </h1>
              {viewDetails && (
                <Button
                  variant="outline"
                  className="text-content-70 rounded-4xl text-sm"
                >
                  View Details
                </Button>
              )}
            </div>
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Image
                src="/tokens/usdc.svg"
                alt="USDC"
                width={24}
                height={24}
                className="size-8"
              />
              <span className="text-content-100 text-sm font-semibold md:text-base">
                USDC
              </span>
            </div>
            <span className="text-content-100 text-sm font-semibold md:text-base">
              {usdcText} USDC
            </span>
          </div>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Image
                src="/tokens/arx.svg"
                alt="ARX"
                width={24}
                height={24}
                className="size-8"
              />
              <span className="text-content-100 text-sm font-semibold md:text-base">
                ARX
              </span>
            </div>
            <span className="text-content-100 text-sm font-semibold md:text-base">
              {arxText} ARX
            </span>
          </div>
          <Separator orientation="horizontal" />
          <h1 className="text-base-primary text-base font-semibold sm:text-lg lg:text-xl">
            Your Position
          </h1>
          <div className="flex items-center justify-between">
            <span className="text-content-70 text-sm md:text-base">
              LP Tokens
            </span>
            <span className="text-content-100 text-sm font-semibold md:text-base">
              {lpText}
            </span>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-content-70 text-sm md:text-base">
              Your Share
            </span>
            <span className="text-content-100 text-sm font-semibold md:text-base">
              {shareText}
            </span>
          </div>
        </CardContent>
      </Card>
    );
  },
);

PoolBalanceWidget.displayName = "PoolBalanceWidget";
