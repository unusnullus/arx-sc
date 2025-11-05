import { useMemo } from "react";

import { useAccount, useBalance } from "wagmi";

import { useChain } from "@/entities/chain";

export const useWalletBalance = (): {
  balance: bigint | undefined;
  formattedBalance: string;
  symbol: string;
  decimals: number;
  isLoading: boolean;
  isError: boolean;
  error: Error | null;
} => {
  const { address, isConnected } = useAccount();
  const { currentChain } = useChain();

  const { data, isLoading, isError, error } = useBalance({
    address,
    query: {
      enabled: isConnected && !!address && !!currentChain,
    },
  });

  const formattedBalance = useMemo(() => {
    if (!data?.formatted) return "0.00";
    return data.formatted;
  }, [data?.formatted]);

  return {
    balance: data?.value,
    formattedBalance,
    symbol: data?.symbol || currentChain?.nativeCurrency.symbol || "ETH",
    decimals: data?.decimals || currentChain?.nativeCurrency.decimals || 18,
    isLoading,
    isError,
    error,
  };
};
