"use client";

import { memo, useCallback, useMemo } from "react";

import { useAccount, useBalance } from "wagmi";

import { PermitSettings, usePermit } from "@/entities/permit";
import { useConnectionCheck } from "@/entities/wallet";
import { useZapAndBuy, useBuyWithUSDC } from "@/entities/transactions";
import {
  Token,
  isNativeToken,
  addressesByChain,
  FALLBACK_CHAIN_ID,
} from "@arx/config";
import { parseUnitsSafe } from "@arx/ui/lib";
import { Button, Spinner } from "@arx/ui/components";

const BuyButtonBase = ({
  token,
  amount,
  permitSettings,
  onResetInput,
}: {
  token: Token | null;
  amount: string;
  permitSettings: PermitSettings;
  onResetInput: () => void;
}) => {
  const { address, chainId } = useAccount();
  const { checkConnection } = useConnectionCheck();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;

  const cfg = useMemo(
    () => addressesByChain[targetChainId] || {},
    [targetChainId],
  );

  const { data: balance } = useBalance({
    address,
    ...(!isNativeToken(token?.address) && {
      token: token?.address,
    }),
    query: {
      enabled: !!address && !!token?.address,
    },
  });

  const {
    zapAndBuy,
    zapAndBuyWithPermit,
    isLoading: isZapLoading,
  } = useZapAndBuy();
  const { buyWithUSDC, isLoading: isBuyWithUSDCLoading } = useBuyWithUSDC();
  const { createPermit, isLoading: isPermitLoading } = usePermit(token);

  const isUSDC = useMemo(
    () => cfg.USDC && token?.address.toLowerCase() === cfg.USDC.toLowerCase(),
    [cfg.USDC, token?.address],
  );

  const handleBuy = useCallback(async () => {
    if (!checkConnection()) return;

    try {
      if (isUSDC) {
        await buyWithUSDC({ amount });
        onResetInput();
        return;
      }

      const percent = permitSettings.slippage ?? 1;
      const slippageBps = BigInt(Math.round(percent * 100));

      if (isNativeToken(token?.address)) {
        await zapAndBuy({
          token,
          amount,
          slippageBps,
        });
        onResetInput();
        return;
      }

      if (permitSettings.approve) {
        const spender = cfg.ARX_ZAP_ROUTER as `0x${string}` | undefined;
        if (!spender) {
          console.error("ARX_ZAP_ROUTER address not found");
          return;
        }
        const permitParams = await createPermit(amount, spender);

        if (!permitParams) return;

        await zapAndBuyWithPermit({
          token,
          amount,
          permitParams,
          slippageBps,
        });
        onResetInput();
        return;
      }

      await zapAndBuy({
        token,
        amount,
        slippageBps,
      });
      onResetInput();
    } catch (error) {
      console.error("Buy failed:", error);
    }
  }, [
    checkConnection,
    isUSDC,
    buyWithUSDC,
    amount,
    permitSettings.slippage,
    permitSettings.approve,
    token,
    zapAndBuy,
    createPermit,
    zapAndBuyWithPermit,
    onResetInput,
    cfg.ARX_ZAP_ROUTER,
  ]);

  const isLoading = isZapLoading || isBuyWithUSDCLoading || isPermitLoading;
  const isInsufficientBalance =
    balance?.value !== undefined &&
    balance.value < parseUnitsSafe(amount, token?.decimals ?? 0);

  const isDisabled =
    isLoading ||
    !amount ||
    Number(amount) === 0 ||
    isInsufficientBalance ||
    !token;

  return (
    <Button
      className="text-content-100 bg-white-10 hover:bg-white-15 h-12 w-full rounded-[100px] py-3 text-base font-semibold"
      onClick={handleBuy}
      disabled={isDisabled && !!address}
    >
      {isLoading ? (
        <div className="flex items-end gap-0.5">
          Processing
          <Spinner variant="ellipsis" />
        </div>
      ) : (
        "Buy ARX"
      )}
    </Button>
  );
};

export const BuyButton = memo(BuyButtonBase);
