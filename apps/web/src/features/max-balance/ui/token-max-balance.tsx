import { memo, useCallback } from "react";

import { useAccount, useBalance } from "wagmi";

import { Token, isNativeToken } from "@arx/config";
import { useMounted } from "@arx/ui/hooks";
import { cn, formatUnitsSafe, truncateFromUnits } from "@arx/ui/lib";
import { Button, Spinner } from "@arx/ui/components";

export const TokenMaxBalanceBase = ({
  token,
  onMaxBalance,
  userBalance,
}: {
  token: Token;
  onMaxBalance: (value: string) => void;
  userBalance?: bigint;
}) => {
  const mounted = useMounted();
  const { address: userAddress, isConnecting, isReconnecting } = useAccount();

  const { data: balance, isLoading: isBalanceLoading } = useBalance({
    address: userAddress,
    ...(!isNativeToken(token.address) && { token: token.address }),
    query: {
      enabled: mounted && !!userAddress,
    },
  });

  const handleMaxBalance = useCallback(() => {
    let value: bigint | null = null;
    if (balance?.value) {
      value = balance.value;
    } else if (typeof userBalance === "bigint") {
      value = userBalance;
    }
    if (!value) return;
    onMaxBalance(formatUnitsSafe(value ?? BigInt(0), token.decimals));
  }, [balance, onMaxBalance, token.decimals, userBalance]);

  if (!userAddress) {
    return null;
  }

  const isLoading = isConnecting || isReconnecting || isBalanceLoading;
  const displayValue = userBalance ?? balance?.value ?? BigInt(0);
  const maxBalance = truncateFromUnits(displayValue, token.decimals, 6);

  return (
    <Button
      variant="ghost"
      onClick={handleMaxBalance}
      className={cn("h-fit p-0 font-normal", {
        "cursor-wait": isLoading,
      })}
      asChild
      aria-label={`Set maximum balance: ${maxBalance} ${token.symbol}`}
      disabled={isLoading || displayValue === BigInt(0)}
    >
      <span className="text-content-70 text-xs sm:text-sm">
        Max:{" "}
        {isLoading ? (
          <Spinner aria-label="Loading balance" role="status" />
        ) : (
          <span aria-label={`${maxBalance} ${token.symbol}`}>{maxBalance}</span>
        )}
      </span>
    </Button>
  );
};

export const TokenMaxBalance = memo(TokenMaxBalanceBase);
