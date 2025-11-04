import { memo } from "react";

import { AlertCircle } from "lucide-react";
import { useAccount, useEstimateFeesPerGas } from "wagmi";

import { FALLBACK_CHAIN_ID } from "@arx/config";
import { cn, truncateDecimals } from "@arx/ui/lib";
import { Spinner } from "@arx/ui/components";

export const EstimatedFeesPerGasBase = ({
  className,
}: {
  className?: string;
}) => {
  const { chainId } = useAccount();

  const {
    data: feeData,
    isLoading,
    error,
  } = useEstimateFeesPerGas({
    chainId: chainId ?? FALLBACK_CHAIN_ID,
    query: {
      refetchInterval: 12 * 1000,
      enabled: !!chainId || !!FALLBACK_CHAIN_ID,
    },
  });

  if (error) {
    return (
      <div
        className={cn(
          "text-error flex items-center gap-1 text-xs sm:text-sm",
          className,
        )}
        role="alert"
        aria-label="Error fetching network fees"
      >
        <AlertCircle className="h-4" aria-hidden="true" />
        <span className="text-error text-xs sm:text-sm">
          Error fetching fees
        </span>
      </div>
    );
  }

  if (isLoading) {
    return (
      <div
        className={cn(
          "text-t-secondary flex items-center gap-1 text-xs sm:text-sm",
          className,
        )}
        aria-label="Loading network fees"
        role="status"
      >
        <Spinner variant="ellipsis" className="h-4" aria-hidden="true" />
        <span>Gwei</span>
      </div>
    );
  }

  const feeAmount = truncateDecimals(
    feeData?.formatted?.maxFeePerGas ?? "0",
    6,
  );

  return (
    <div
      className={cn("text-content-70 text-xs sm:text-sm", className)}
      aria-label={`Estimated network fee: ${feeAmount} Gwei`}
    >
      {feeAmount} Gwei
    </div>
  );
};

export const EstimatedFeesPerGas = memo(EstimatedFeesPerGasBase);
