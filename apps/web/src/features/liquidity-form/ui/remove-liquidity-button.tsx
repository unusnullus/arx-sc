import { memo, useCallback, useMemo, useState } from "react";

import { toast } from "@arx/ui/components";
import { Address, parseUnits } from "viem";
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useWriteContract,
} from "wagmi";

import { addressesByChain, FALLBACK_CHAIN_ID } from "@arx/config";
import { ERC20_ABI, RATE_POOL_ABI } from "@arx/abi";
import { Button, Spinner } from "@arx/ui/components";
import { useQueryClient } from "@tanstack/react-query";

interface RemoveLiquidityButtonProps {
  amount: string;
  onResetInput: () => void;
}

const RemoveLiquidityButtonBase = ({
  amount,
  onResetInput,
}: RemoveLiquidityButtonProps) => {
  const { address, chainId } = useAccount();
  const publicClient = usePublicClient();
  const queryClient = useQueryClient();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;

  const ratePool = useMemo(
    () => addressesByChain[targetChainId]?.RATE_POOL ?? undefined,
    [targetChainId],
  );

  const { data: lpDecimals } = useReadContract({
    address: ratePool!,
    abi: RATE_POOL_ABI,
    functionName: "decimals",
    query: { enabled: Boolean(ratePool) },
  });

  const [isBusy, setIsBusy] = useState(false);
  const { writeContractAsync } = useWriteContract();

  const handleRemoveLiquidity = useCallback(async () => {
    if (!amount || Number(amount) === 0) {
      toast.error("Invalid amount");
      return;
    }
    if (!address) {
      toast.error("Wallet not connected");
      return;
    }
    if (!ratePool) {
      toast.error("Unsupported network");
      return;
    }

    try {
      setIsBusy(true);
      const lpAmount = parseUnits(amount, lpDecimals as number);

      const userLp = (await publicClient?.readContract({
        address: ratePool as Address,
        abi: ERC20_ABI,
        functionName: "balanceOf",
        args: [address as Address],
      })) as bigint | undefined;

      if ((userLp ?? BigInt(0)) < lpAmount) {
        toast.error("Insufficient balance");
        setIsBusy(false);
        return;
      }

      const tx = await writeContractAsync({
        address: ratePool as Address,
        abi: RATE_POOL_ABI,
        functionName: "removeLiquidity",
        args: [lpAmount],
      });
      toast.info("Transaction sent");
      await publicClient?.waitForTransactionReceipt({ hash: tx });
      toast.success("Transaction successful");
      onResetInput();

      queryClient.invalidateQueries({
        queryKey: [
          "readContract",
          {
            functionName: "balanceOf",
          },
        ],
      });
    } catch (error) {
      console.error("Remove liquidity failed:", error);
      toast.error("Transaction failed");
    } finally {
      setIsBusy(false);
    }
  }, [
    address,
    amount,
    lpDecimals,
    onResetInput,
    publicClient,
    ratePool,
    writeContractAsync,
    queryClient,
  ]);

  const isDisabled = isBusy || !amount || Number(amount) === 0;

  return (
    <Button
      className="text-content-100 bg-white-10 hover:bg-white-15 h-12 w-full rounded-[100px] py-3 text-base font-semibold"
      onClick={handleRemoveLiquidity}
      disabled={isDisabled}
    >
      {isBusy ? (
        <div className="flex items-end gap-0.5">
          Processing
          <Spinner variant="ellipsis" />
        </div>
      ) : (
        "Remove Liquidity"
      )}
    </Button>
  );
};

export const RemoveLiquidityButton = memo(RemoveLiquidityButtonBase);
