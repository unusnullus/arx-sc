import { ReactElement, useCallback, useEffect, useState } from "react";

import Image from "next/image";

import { useAccount } from "wagmi";

import { EstimatedFeesPerGas } from "@/entities/fees";
import { PermitSettings } from "@/entities/permit";
import { useConnectionCheck } from "@/entities/wallet";
import {
  FALLBACK_CHAIN_ID,
  Token,
  getTokenBySymbolSafe,
  getTokensByChainIdSafe,
} from "@arx/config";
import { useDebounceValue } from "@arx/ui/hooks";

import { BuyButton } from "./buy-button";

export const BuyForm = ({
  renderSelectCoin,
  renderCoinAmountInput,
  renderMaxBalance,
  permitSettings,
}: {
  renderSelectCoin: (onSelect: (token: Token) => void) => ReactElement;
  renderCoinAmountInput: (
    token: Token,
    value: string,
    onChange: (value: string) => void,
  ) => ReactElement;
  renderMaxBalance: (
    token: Token,
    onMaxBalance: (value: string) => void,
  ) => ReactElement;
  permitSettings: PermitSettings;
}) => {
  const { isConnected } = useConnectionCheck();
  const { chainId } = useAccount();

  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;
  const [amount, setAmount] = useState<string>("");
  const arxToken = getTokenBySymbolSafe("ARX", targetChainId);
  const availableTokens = getTokensByChainIdSafe(targetChainId);
  const [token, setToken] = useState<Token | null>(
    availableTokens?.[0] || null,
  );

  const debouncedAmount = useDebounceValue(amount, 300);

  const handleResetInput = useCallback(() => {
    setAmount("");
  }, []);

  const handleTokenChange = useCallback(
    (newToken: Token | null) => {
      if (!newToken) return;

      setToken(newToken);
      handleResetInput();
    },
    [handleResetInput],
  );

  const handleAmountChange = useCallback((newAmount: string) => {
    setAmount(newAmount);
  }, []);

  useEffect(() => {
    if (!isConnected) {
      handleResetInput();
    }
    if (availableTokens && availableTokens.length > 0 && !token) {
      setToken(availableTokens[0]);
    }
  }, [isConnected, chainId, handleResetInput, availableTokens, token]);

  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-col">
        <div className="flex flex-col gap-2">
          <div className="border-white-10 flex flex-col gap-2 rounded-2xl border bg-black px-4 py-3 pb-4">
            <div className="flex items-center justify-between gap-2">
              <span className="text-content-70 text-xs sm:text-sm">
                Pay with
              </span>
              {token && renderMaxBalance(token, (value) => setAmount(value))}
            </div>
            <div className="flex items-center justify-between gap-2">
              <div className="flex-1">
                {renderSelectCoin(handleTokenChange)}
              </div>
              <div className="flex-1">
                {token &&
                  renderCoinAmountInput(token, amount, handleAmountChange)}
              </div>
            </div>
          </div>
          <div className="border-white-10 flex items-center justify-between gap-2 rounded-2xl border bg-black px-4 py-3">
            <div className="flex flex-1 flex-col gap-2">
              <span className="text-content-70 text-xs sm:text-sm">Buy</span>
              <div className="flex h-9 items-center gap-2">
                <div className="relative">
                  <Image
                    src={arxToken?.logoURI || "/tokens/arx.svg"}
                    alt={arxToken?.name || "ARX"}
                    width={36}
                    height={36}
                    className="size-6 sm:size-7 md:size-8 lg:size-9"
                  />
                  {token && (
                    <Image
                      src={token.logoURI || "/tokens/eth.svg"}
                      alt={token.symbol}
                      width={16}
                      height={16}
                      className="border-input absolute -right-1 -bottom-1 size-4 rounded-full border-2 lg:size-5"
                    />
                  )}
                </div>
                <span className="text-content-70 text-lg font-semibold lg:text-xl">
                  ARX
                </span>
              </div>
            </div>
            <div className="flex-1 text-right">
              {token && amount && (
                <div className="text-content-70 text-lg">
                  ~{Number(amount).toFixed(2)} {arxToken?.symbol || "ARX"}
                </div>
              )}
            </div>
          </div>
        </div>
        <div className="flex items-center justify-between px-4 py-3">
          <span className="text-content-70 text-xs sm:text-sm">
            Estimated network fee
          </span>
          <EstimatedFeesPerGas />
        </div>
      </div>

      {token && (
        <BuyButton
          token={token}
          amount={debouncedAmount}
          permitSettings={permitSettings}
          onResetInput={handleResetInput}
        />
      )}
    </div>
  );
};
