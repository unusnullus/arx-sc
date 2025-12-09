import { useCallback, useEffect, useMemo, useState } from "react";

import { Address } from "viem";
import { useAccount, useReadContract } from "wagmi";

import { useConnectionCheck } from "@/entities/wallet";
import {
  FALLBACK_CHAIN_ID,
  type Token,
  addressesByChain,
  getTokenBySymbolSafe,
  getTokensByChainIdSafe,
} from "@arx/config";

import { LiquidityAction, LiquidityFormProps, LiquidityStep } from "../types";
import { AddLiquidityButton } from "./add-liquidity-button";
import { LiquiditySteps } from "./liquidity-steps";
import { RemoveLiquidityButton } from "./remove-liquidity-button";
import { SwapForm } from "./swap-pool-form";
import { useDebounceValue } from "@arx/ui/hooks";
import { RATE_POOL_ABI } from "@arx/abi";
import { Tabs, TabsList, TabsTrigger } from "@arx/ui/components";

export const LiquidityForm = ({
  renderCoinAmountInput,
  renderMaxBalance,
}: LiquidityFormProps) => {
  const { isConnected } = useConnectionCheck();
  const { chainId, address } = useAccount();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;
  const [activeTab, setActiveTab] = useState<LiquidityAction>("add");
  const [usdcAmount, setUsdcAmount] = useState<string>("");
  const [arxAmount, setArxAmount] = useState<string>("");
  const [addSteps, setAddSteps] = useState<LiquidityStep[]>([
    {
      id: "approve-usdc",
      title: "Approve USDC",
      description: "Approve USDC to the rate pool",
      status: "pending",
    },
    {
      id: "approve-arx",
      title: "Approve ARX",
      description: "Approve ARX to the rate pool",
      status: "pending",
    },
    {
      id: "add-liquidity",
      title: "Add Liquidity",
      description: "Add liquidity to the rate pool",
      status: "pending",
    },
  ]);

  const tokens = getTokensByChainIdSafe(targetChainId);
  const usdcToken = getTokenBySymbolSafe("USDC", targetChainId);
  const arxToken = getTokenBySymbolSafe("ARX", targetChainId);

  const cfg = useMemo(
    () => addressesByChain[targetChainId] || {},
    [targetChainId],
  );

  const { data: userLp } = useReadContract({
    address: cfg.RATE_POOL!,
    abi: RATE_POOL_ABI,
    functionName: "balanceOf",
    args: [address! as Address],
    query: { enabled: Boolean(cfg.RATE_POOL && address) },
  });

  const debouncedUsdcAmount = useDebounceValue(usdcAmount, 300);
  const debouncedArxAmount = useDebounceValue(arxAmount, 300);

  const { data: lpDecimals } = useReadContract({
    address: cfg.RATE_POOL!,
    abi: RATE_POOL_ABI,
    functionName: "decimals",
    query: { enabled: Boolean(cfg.RATE_POOL) },
  });

  const handleUsdcAmountChange = useCallback((newAmount: string) => {
    setUsdcAmount(newAmount);
  }, []);
  const handleArxAmountChange = useCallback((newAmount: string) => {
    setArxAmount(newAmount);
  }, []);

  const handleResetInput = useCallback(() => {
    setUsdcAmount("");
    setArxAmount("");
    setAddSteps([
      {
        id: "approve-usdc",
        title: "Approve USDC",
        description: "Approve USDC to the rate pool",
        status: "pending",
      },
      {
        id: "approve-arx",
        title: "Approve ARX",
        description: "Approve ARX to the rate pool",
        status: "pending",
      },
      {
        id: "add-liquidity",
        title: "Add Liquidity",
        description: "Add liquidity to the rate pool",
        status: "pending",
      },
    ]);
  }, []);

  const handleTabChange = useCallback(
    (value: string) => {
      setActiveTab(value as LiquidityAction);
      handleResetInput();
      setAddSteps([
        {
          id: "approve-usdc",
          title: "Approve USDC",
          description: "Approve USDC to the rate pool",
          status: "pending",
        },
        {
          id: "approve-arx",
          title: "Approve ARX",
          description: "Approve ARX to the rate pool",
          status: "pending",
        },
        {
          id: "add-liquidity",
          title: "Add Liquidity",
          description: "Add liquidity to the rate pool",
          status: "pending",
        },
      ]);
    },
    [handleResetInput],
  );

  const updateStepStatus = useCallback(
    (stepId: string, status: LiquidityStep["status"]) => {
      setAddSteps((prev) =>
        prev.map((step) => (step.id === stepId ? { ...step, status } : step)),
      );
    },
    [],
  );

  useEffect(() => {
    if (!isConnected) {
      handleResetInput();
    }
  }, [isConnected, chainId, handleResetInput]);

  if (!usdcToken || !arxToken || !tokens || !tokens.length) {
    return (
      <div className="flex flex-col gap-6 py-4">
        <div className="text-muted-foreground text-center">
          Network not supported
        </div>
      </div>
    );
  }

  const renderTabContent = () => {
    switch (activeTab) {
      case "add":
        return (
          <div className="flex flex-col gap-6">
            <LiquiditySteps steps={addSteps} />
            <div className="flex flex-col gap-3">
              <div className="border-white-10 flex flex-col gap-2 rounded-2xl bg-black p-4 pt-3">
                <div className="flex items-center justify-between gap-2">
                  <span className="text-content-70 text-xs sm:text-sm">
                    Amount USDC
                  </span>
                  {usdcToken &&
                    renderMaxBalance(usdcToken, (value) =>
                      setUsdcAmount(value),
                    )}
                </div>
                <div className="flex items-center justify-between gap-2">
                  <div className="flex-1">
                    {renderCoinAmountInput(
                      usdcToken!,
                      usdcAmount,
                      handleUsdcAmountChange,
                    )}
                  </div>
                </div>
              </div>
              <div className="border-white-10 flex flex-col gap-2 rounded-2xl bg-black p-4 pt-3">
                <div className="flex items-center justify-between gap-2">
                  <span className="text-content-70 text-xs sm:text-sm">
                    Amount ARX
                  </span>
                  {arxToken &&
                    renderMaxBalance(
                      { ...arxToken, address: cfg.ARX as `0x${string}` },
                      (value) => setArxAmount(value),
                    )}
                </div>
                <div className="flex items-center justify-between gap-2">
                  <div className="flex-1">
                    {renderCoinAmountInput(
                      { ...arxToken, address: cfg.ARX as `0x${string}` },
                      arxAmount,
                      handleArxAmountChange,
                    )}
                  </div>
                </div>
              </div>
            </div>
            <AddLiquidityButton
              usdcAmount={debouncedUsdcAmount}
              arxAmount={debouncedArxAmount}
              onResetInput={handleResetInput}
              onStepStatusChange={updateStepStatus}
            />
          </div>
        );

      case "remove":
        return (
          <div className="flex flex-col gap-6">
            <LiquiditySteps
              steps={[
                {
                  id: "remove-liquidity",
                  title: "Remove Liquidity",
                  description: "Remove liquidity from the rate pool",
                  status: "pending",
                },
              ]}
            />
            <div className="flex flex-col">
              <div className="border-white-10 flex flex-col gap-2 rounded-2xl border bg-black p-4 pt-3">
                <div className="flex items-center justify-between gap-2">
                  <span className="text-content-70 text-xs sm:text-sm">
                    LP Amount to Remove
                  </span>
                  {(() => {
                    if (!cfg.RATE_POOL) return null;

                    const lpToken: Token = {
                      address: cfg.RATE_POOL as `0x${string}`,
                      symbol: "LP",
                      name: "LP Token",
                      decimals: lpDecimals as number,
                      logoURI: "/icons/cup.svg",
                      chainId: targetChainId,
                    } as const;

                    return renderMaxBalance(lpToken, (value) =>
                      setUsdcAmount(value),
                    );
                  })()}
                </div>
                <div className="flex items-center justify-between gap-2">
                  <div className="flex-1">
                    {(() => {
                      if (!cfg.RATE_POOL) return null;

                      const lpToken: Token = {
                        address: cfg.RATE_POOL as `0x${string}`,
                        symbol: "LP",
                        name: "LP Token",
                        decimals: lpDecimals as number,
                        logoURI: "/icons/cup.svg",
                        chainId: targetChainId,
                      } as const;

                      return renderCoinAmountInput(
                        lpToken,
                        usdcAmount,
                        handleUsdcAmountChange,
                        userLp ?? BigInt(0),
                      );
                    })()}
                  </div>
                  <div className="text-base-secondary text-sm">LP Tokens</div>
                </div>
              </div>
            </div>
            <RemoveLiquidityButton
              amount={debouncedUsdcAmount}
              onResetInput={handleResetInput}
            />
          </div>
        );

      case "swap":
        return (
          <SwapForm
            usdcToken={usdcToken}
            arxToken={{ ...arxToken, address: cfg.ARX as `0x${string}` }}
            renderCoinAmountInput={renderCoinAmountInput}
            renderMaxBalance={renderMaxBalance}
          />
        );

      default:
        return null;
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <Tabs value={activeTab} onValueChange={handleTabChange}>
          <TabsList className="md:h-11">
            <TabsTrigger value="add" className="px-4 md:h-9">
              Add
            </TabsTrigger>
            <TabsTrigger value="remove" className="px-4 md:h-9">
              Remove
            </TabsTrigger>
            <TabsTrigger value="swap" className="px-4 md:h-9">
              Swap
            </TabsTrigger>
          </TabsList>
        </Tabs>
      </div>
      {renderTabContent()}
    </div>
  );
};
