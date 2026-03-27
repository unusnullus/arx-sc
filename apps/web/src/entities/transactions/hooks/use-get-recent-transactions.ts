"use client";

import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { usePublicClient } from "wagmi";
import { formatUnits } from "viem";

import { addressesByChain } from "@arx/config";
import { ARX_TOKEN_SALE_ABI } from "@arx/abi";

export interface RecentTransaction {
  tx: string;
  buyer: string;
  usdc: string;
  arx: string;
  block: bigint;
  datetime: string;
  status: "success" | "failed";
}

export const useGetRecentTransactions = (targetChainId: number) => {
  const publicClient = usePublicClient({ chainId: targetChainId });

  const cfg = useMemo(
    () => addressesByChain[targetChainId] || {},
    [targetChainId],
  );

  const saleAddress = cfg.ARX_TOKEN_SALE as `0x${string}` | undefined;

  const { data, isLoading, isError, error } = useQuery({
    queryKey: ["recent-transactions", targetChainId, saleAddress],
    queryFn: async (): Promise<RecentTransaction[]> => {
      if (!publicClient || !saleAddress) {
        return [];
      }

      const currentBlock = await publicClient.getBlockNumber();
      const fromBlock = BigInt(Math.max(0, Number(currentBlock) - 1000000));
      const toBlock = currentBlock;

      const logs = await publicClient.getLogs({
        address: saleAddress,
        event: {
          type: "event",
          name: "Purchased",
          inputs:
            ARX_TOKEN_SALE_ABI.find(
              (item) => item.type === "event" && item.name === "Purchased",
            )?.inputs || [],
        },
        fromBlock,
        toBlock,
      });

      const transactions = await Promise.all(
        logs.map(async (log) => {
          const [block, receipt] = await Promise.all([
            publicClient.getBlock({
              blockNumber: log.blockNumber,
            }),
            publicClient.getTransactionReceipt({
              hash: log.transactionHash,
            }),
          ]);
          const date = new Date(Number(block.timestamp) * 1000);

          const args = log.args as {
            buyer?: `0x${string}`;
            usdcAmount?: bigint;
            arxAmount?: bigint;
          };

          return {
            tx: log.transactionHash,
            buyer: args.buyer || "",
            usdc: formatUnits(args.usdcAmount || BigInt(0), 6),
            arx: formatUnits(args.arxAmount || BigInt(0), 6),
            block: log.blockNumber,
            datetime: date.toISOString(),
            status:
              receipt.status === "success"
                ? ("success" as const)
                : ("failed" as const),
          };
        }),
      );

      return transactions
        .sort((a, b) => {
          if (a.block > b.block) return -1;
          if (a.block < b.block) return 1;
          return 0;
        })
        .slice(0, 5);
    },
    enabled: !!publicClient && !!saleAddress,
    gcTime: 5 * 60 * 1000,
    refetchInterval: 30 * 1000,
  });

  return {
    transactions: data || [],
    isLoading,
    isError,
    error,
  };
};
