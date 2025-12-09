import { useMemo } from "react";

import Image from "next/image";

import { AlertCircle } from "lucide-react";
import { useAccount, useBalance } from "wagmi";

import {
  FALLBACK_CHAIN_ID,
  getTokenByAddress,
  isNativeToken,
} from "@arx/config";
import { useMounted } from "@arx/ui/hooks";
import { formatUnitsSafe, truncateDecimals } from "@arx/ui/lib";
import { Spinner } from "@arx/ui/components";

export const SelectCoinItem = ({
  userAddress,
  tokenAddress,
}: {
  userAddress?: `0x${string}`;
  tokenAddress: `0x${string}`;
}) => {
  const mounted = useMounted();
  const { chainId } = useAccount();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;

  const {
    data: balance,
    isLoading,
    isError,
  } = useBalance({
    address: userAddress,
    ...(!isNativeToken(tokenAddress) && { token: tokenAddress }),
    query: {
      enabled: mounted && !!userAddress,
    },
  });

  const token = getTokenByAddress(tokenAddress, targetChainId);

  const formattedBalance = useMemo(() => {
    if (!balance) return "0.00";
    return truncateDecimals(
      formatUnitsSafe(balance.value, balance.decimals),
      6,
    );
  }, [balance]);

  const balanceContent = useMemo(() => {
    if (isLoading) return <Spinner variant="ellipsis" />;

    if (isError)
      return (
        <div className="text-error flex items-center gap-1 text-right text-xs">
          <AlertCircle className="text-error h-4 w-4" />
          Fetch error
        </div>
      );

    return (
      <p
        className="text-muted-foreground text-sm"
        aria-label={`Balance: ${formattedBalance}`}
      >
        {formattedBalance}
      </p>
    );
  }, [isLoading, isError, formattedBalance]);

  if (!token) return null;

  const { symbol, name, logoURI } = token;

  return (
    <div
      className="flex w-full items-center justify-between gap-2"
      aria-label={`${name} (${symbol}) token option`}
    >
      <div className="flex items-center gap-2">
        <Image
          src={logoURI}
          alt={`${name} token logo`}
          width={32}
          height={32}
          role="img"
          aria-hidden="false"
        />
        <div>
          <p className="text-sm font-medium" aria-label="Token symbol">
            {symbol}
          </p>
          <p className="text-content-70 text-xs" aria-label="Token name">
            {name}
          </p>
        </div>
      </div>
      {balanceContent}
    </div>
  );
};
