"use client";

import { memo, useCallback, useMemo } from "react";

import { useAccount, useBalance, useChainId } from "wagmi";

import { PermitSettings, usePermit } from "@/entities/permit";
import { useConnectionCheck } from "@/entities/wallet";
import { useZapAndBuy } from "@/entities/transactions";
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
  token: Token;
  amount: string;
  permitSettings: PermitSettings;
  onResetInput: () => void;
}) => {
  const { address } = useAccount();
  const chainId = useChainId();
  const { checkConnection } = useConnectionCheck();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;
  const cfg = useMemo(
    () => addressesByChain[targetChainId] || {},
    [targetChainId],
  );

  const { data: balance } = useBalance({
    address,
    ...(!isNativeToken(token.address) && { token: token.address }),
    query: {
      enabled: !!address && !!token.address,
    },
  });

  const {
    zapAndBuy,
    zapAndBuyWithPermit,
    isLoading: isZapLoading,
  } = useZapAndBuy();
  const { createPermit, isLoading: isPermitLoading } = usePermit(token);

  const handleBuy = useCallback(async () => {
    if (!checkConnection()) return;

    try {
      const percent = permitSettings.slippage ?? 1;
      const slippageBps = BigInt(Math.round(percent * 100));

      if (isNativeToken(token.address)) {
        await zapAndBuy({
          token,
          amount,
          slippageBps,
        });
        onResetInput();
        return;
      }

      if (permitSettings.approve) {
        // For zapAndBuyWithPermit, spender should be ARX_ZAP_ROUTER
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
    permitSettings.slippage,
    permitSettings.approve,
    token,
    zapAndBuy,
    amount,
    createPermit,
    zapAndBuyWithPermit,
    onResetInput,
    cfg.ARX_ZAP_ROUTER,
  ]);

  const isLoading = isZapLoading || isPermitLoading;
  const isInsufficientBalance =
    balance?.value !== undefined &&
    balance.value < parseUnitsSafe(amount, token.decimals);

  const isDisabled =
    isLoading || !amount || Number(amount) === 0 || isInsufficientBalance;

  return (
    <Button
      className="text-content-100 bg-white-10 h-12 w-full rounded-[100px] py-3 text-base font-semibold"
      onClick={handleBuy}
      disabled={isDisabled}
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
