import { memo, useCallback, useMemo, useState } from "react";

import { toast } from "@arx/ui/components";
import { Address, parseUnits } from "viem";
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useWriteContract,
} from "wagmi";

import {
  addressesByChain,
  FALLBACK_CHAIN_ID,
  getTokenBySymbolSafe,
} from "@arx/config";
import { Button, Spinner } from "@arx/ui/components";
import { ERC20_ABI, RATE_POOL_ABI } from "@arx/abi";

import { LiquidityStep } from "../types";
import { useQueryClient } from "@tanstack/react-query";

interface AddLiquidityButtonProps {
  usdcAmount: string;
  arxAmount: string;
  onResetInput: () => void;
  onStepStatusChange: (stepId: string, status: LiquidityStep["status"]) => void;
}

const AddLiquidityButtonBase = ({
  usdcAmount,
  arxAmount,
  onResetInput,
  onStepStatusChange,
}: AddLiquidityButtonProps) => {
  const { address, chainId } = useAccount();
  const publicClient = usePublicClient();
  const queryClient = useQueryClient();

  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;

  const usdc = useMemo(
    () => getTokenBySymbolSafe("USDC", targetChainId),
    [targetChainId],
  );
  const arx = useMemo(
    () => getTokenBySymbolSafe("ARX", targetChainId),
    [targetChainId],
  );

  const cfg = useMemo(
    () => addressesByChain[targetChainId] || {},
    [targetChainId],
  );

  const [isBusy, setIsBusy] = useState(false);

  const { writeContractAsync } = useWriteContract();

  const { refetch: refetchUsdcAllowance } = useReadContract({
    address: (usdc?.address ?? undefined) as Address | undefined,
    abi: ERC20_ABI,
    functionName: "allowance",
    query: { enabled: false },
  });
  const { refetch: refetchArxAllowance } = useReadContract({
    address: (arx?.address ?? undefined) as Address | undefined,
    abi: ERC20_ABI,
    functionName: "allowance",
    query: { enabled: false },
  });

  const approveIfNeeded = useCallback(
    async (tokenAddr: Address, spender: Address, need: bigint) => {
      if (!address || !publicClient) return;
      const { data: allowance } = await (tokenAddr ===
      (usdc?.address as Address)
        ? refetchUsdcAllowance({
            // @ts-expect-error - refetch error
            args: [address as Address, spender],
            throwOnError: false,
            cancelRefetch: false,
          })
        : refetchArxAllowance({
            // @ts-expect-error - refetch error
            args: [address as Address, spender],
            throwOnError: false,
            cancelRefetch: false,
          }));

      const current = (allowance as bigint | undefined) ?? 0;
      if (current >= need) return;

      const tx = await writeContractAsync({
        address: tokenAddr,
        abi: ERC20_ABI,
        functionName: "approve",
        args: [spender, need],
      });
      await publicClient.waitForTransactionReceipt({ hash: tx });
    },
    [
      address,
      publicClient,
      refetchUsdcAllowance,
      refetchArxAllowance,
      usdc?.address,
      writeContractAsync,
    ],
  );

  const handleAddLiquidity = useCallback(async () => {
    const hasUsdcAmount = usdcAmount && Number(usdcAmount) > 0;
    const hasArxAmount = arxAmount && Number(arxAmount) > 0;

    if (!hasUsdcAmount && !hasArxAmount) {
      toast.error("Invalid amount");
      return;
    }
    if (!address) {
      toast.error("Wallet not connected");
      return;
    }
    if (!cfg.RATE_POOL || !usdc || !arx) {
      toast.error("Unsupported network");
      return;
    }

    try {
      setIsBusy(true);

      const usdcAmountParsed = hasUsdcAmount
        ? parseUnits(usdcAmount, usdc.decimals)
        : BigInt(0);
      const arxAmountParsed = hasArxAmount
        ? parseUnits(arxAmount, arx.decimals)
        : BigInt(0);

      if (hasUsdcAmount) {
        const usdcBalance = (await publicClient?.readContract({
          address: usdc.address as Address,
          abi: ERC20_ABI,
          functionName: "balanceOf",
          args: [address as Address],
        })) as bigint | undefined;

        if ((usdcBalance ?? BigInt(0)) < usdcAmountParsed) {
          toast.error("Insufficient balance");
          setIsBusy(false);
          return;
        }

        const { data: usdcAllowance } = await refetchUsdcAllowance({
          // @ts-expect-error - refetch error
          args: [address as Address, cfg.RATE_POOL as Address],
          throwOnError: false,
          cancelRefetch: false,
        });

        const currentUsdcAllowance = (usdcAllowance as bigint | undefined) ?? 0;
        if (currentUsdcAllowance < usdcAmountParsed) {
          onStepStatusChange("approve-usdc", "active");
          await approveIfNeeded(
            usdc.address as Address,
            cfg.RATE_POOL as Address,
            usdcAmountParsed,
          );
        }
        onStepStatusChange("approve-usdc", "completed");
      }

      if (hasArxAmount) {
        const arxBalance = (await publicClient?.readContract({
          address: arx.address as Address,
          abi: ERC20_ABI,
          functionName: "balanceOf",
          args: [address as Address],
        })) as bigint | undefined;
        if ((arxBalance ?? BigInt(0)) < arxAmountParsed) {
          toast.error("Insufficient balance");
          setIsBusy(false);
          return;
        }

        const { data: arxAllowance } = await refetchArxAllowance({
          // @ts-expect-error - refetch error
          args: [address as Address, cfg.RATE_POOL as Address],
          throwOnError: false,
          cancelRefetch: false,
        });

        const currentArxAllowance = (arxAllowance as bigint | undefined) ?? 0;
        if (currentArxAllowance < arxAmountParsed) {
          onStepStatusChange("approve-arx", "active");
          await approveIfNeeded(
            cfg.ARX as Address,
            cfg.RATE_POOL as Address,
            arxAmountParsed,
          );
        }
        onStepStatusChange("approve-arx", "completed");
      }

      onStepStatusChange("add-liquidity", "active");
      const tx = await writeContractAsync({
        address: cfg.RATE_POOL as Address,
        abi: RATE_POOL_ABI,
        functionName: "addLiquidity",
        args: [arxAmountParsed, usdcAmountParsed],
      });
      toast.info("Transaction sent");

      onStepStatusChange("add-liquidity", "processing");

      await publicClient?.waitForTransactionReceipt({ hash: tx });

      onStepStatusChange("add-liquidity", "completed");

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
      console.error("Add liquidity failed:", error);
      toast.error("Transaction failed");

      onStepStatusChange("approve-usdc", "pending");
      onStepStatusChange("approve-arx", "pending");
      onStepStatusChange("add-liquidity", "pending");
    } finally {
      setIsBusy(false);
    }
  }, [
    usdcAmount,
    arxAmount,
    address,
    cfg.RATE_POOL,
    cfg.ARX,
    usdc,
    arx,
    onStepStatusChange,
    writeContractAsync,
    publicClient,
    onResetInput,
    queryClient,
    refetchUsdcAllowance,
    approveIfNeeded,
    refetchArxAllowance,
  ]);

  const hasUsdcAmount = !!usdcAmount && Number(usdcAmount) > 0;
  const hasArxAmount = !!arxAmount && Number(arxAmount) > 0;
  const isDisabled = isBusy || (!hasUsdcAmount && !hasArxAmount);

  return (
    <Button
      className="text-content-100 bg-white-10 hover:bg-white-15 h-12 w-full rounded-[100px] py-3 text-base font-semibold"
      onClick={handleAddLiquidity}
      disabled={isDisabled}
    >
      {isBusy ? (
        <div className="flex items-end gap-0.5">
          Processing
          <Spinner variant="ellipsis" />
        </div>
      ) : (
        "Add Liquidity"
      )}
    </Button>
  );
};

export const AddLiquidityButton = memo(AddLiquidityButtonBase);
