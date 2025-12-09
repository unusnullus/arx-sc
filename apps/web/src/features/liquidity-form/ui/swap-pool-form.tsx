import { ReactElement, useCallback, useMemo, useState } from "react";

import Image from "next/image";

import { Repeat } from "lucide-react";
import { useAccount } from "wagmi";

import { FALLBACK_CHAIN_ID, Token } from "@arx/config";
import { Button } from "@arx/ui/components";

import { usePoolSwap, usePoolSwapAmounts, usePoolSwapRate } from "../hooks";

interface SwapFormProps {
  usdcToken: Token;
  arxToken: Token;
  renderCoinAmountInput: (
    token: Token,
    value: string,
    onChange: (value: string) => void,
  ) => ReactElement;
  renderMaxBalance: (
    token: Token,
    onMaxBalance: (value: string) => void,
  ) => ReactElement;
}

export const SwapForm = ({
  usdcToken,
  arxToken,
  renderCoinAmountInput,
  renderMaxBalance,
}: SwapFormProps) => {
  const { chainId } = useAccount();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;

  const [isFromUSDC, setIsFromUSDC] = useState<boolean>(true);

  const fromToken = useMemo(
    () => (isFromUSDC ? usdcToken : arxToken),
    [isFromUSDC, usdcToken, arxToken],
  );
  const toToken = useMemo(
    () => (isFromUSDC ? arxToken : usdcToken),
    [isFromUSDC, arxToken, usdcToken],
  );

  const rateText = usePoolSwapRate({
    fromToken,
    toToken,
    usdcToken,
    isFromUSDC,
    chainId: targetChainId,
  });

  const {
    fromAmount,
    toAmount,
    handleFromAmountChange,
    handleToAmountChange,
    resetAmounts,
    setFromAmount,
    setToAmount,
  } = usePoolSwapAmounts({
    fromToken,
    toToken,
    usdcToken,
    isFromUSDC,
    chainId: targetChainId,
  });

  const { handleSwap } = usePoolSwap({
    fromToken,
    toToken,
    usdcToken,
    isFromUSDC,
    fromAmount,
    chainId: targetChainId,
    onSuccess: resetAmounts,
  });

  const handleSwapDirection = useCallback(() => {
    setIsFromUSDC((prev) => !prev);
    setFromAmount(toAmount);
  }, [toAmount, setFromAmount]);

  const isValid = Boolean(fromAmount) && Number(fromAmount) > 0;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col">
        <div className="border-white-10 flex flex-col gap-2 rounded-2xl border bg-black p-4 pt-3">
          <div className="flex items-center justify-between gap-2">
            <span className="text-content-70 text-xs sm:text-sm">Input</span>
            {renderMaxBalance(fromToken, (v) => setFromAmount(v))}
          </div>
          <div className="flex items-center justify-between gap-2">
            <div className="flex flex-1 items-center">
              <div className="flex items-center gap-2">
                <div className="relative">
                  <Image
                    src={fromToken.logoURI}
                    alt={fromToken.name}
                    width={36}
                    height={36}
                    className="size-6 sm:size-7 md:size-8 lg:size-9"
                  />
                </div>
                <span className="text-base-primary text-base font-semibold lg:text-lg">
                  {fromToken.symbol}
                </span>
              </div>
            </div>
            <div className="flex-1">
              {renderCoinAmountInput(
                fromToken,
                fromAmount,
                handleFromAmountChange,
              )}
            </div>
          </div>
        </div>
        <div className="flex justify-center">
          <div className="relative h-2 w-14">
            <button
              onClick={handleSwapDirection}
              className="border-content-grey hover:bg-white-10/80 absolute top-1/2 left-1/2 z-10 flex h-9 w-9 -translate-x-1/2 -translate-y-1/2 cursor-pointer items-center justify-center rounded-full border bg-black shadow-sm transition-transform hover:rotate-180"
              aria-label="Swap direction"
            >
              <Repeat className="text-content-100 size-4 rotate-90" />
            </button>
          </div>
        </div>
        <div className="border-white-10 flex flex-col gap-2 rounded-2xl border bg-black p-4 pt-3">
          <div className="flex items-center justify-between gap-2">
            <span className="text-content-70 text-xs sm:text-sm">Output</span>
            <div className="flex items-center gap-2">
              <span className="text-content-70 text-xs sm:text-sm">
                Balance:{" "}
              </span>
              {renderMaxBalance(toToken, (v) => setToAmount(v))}
            </div>
          </div>
          <div className="flex items-center justify-between gap-2">
            <div className="flex flex-1 items-center">
              <div className="flex items-center gap-2">
                <div className="relative">
                  <Image
                    src={toToken.logoURI}
                    alt={toToken.name}
                    width={36}
                    height={36}
                    className="size-6 sm:size-7 md:size-8 lg:size-9"
                  />
                </div>
                <span className="text-content-70 text-base font-semibold lg:text-lg">
                  {toToken.symbol}
                </span>
              </div>
            </div>
            <div className="flex-1">
              {renderCoinAmountInput(toToken, toAmount, handleToAmountChange)}
            </div>
          </div>
        </div>
      </div>

      <div className="text-content-70 text-right text-sm">
        Rate: 1 {fromToken.symbol} = {rateText || "-"} {toToken.symbol}
      </div>

      <Button
        onClick={handleSwap}
        disabled={!isValid}
        className="text-content-100 bg-white-10 hover:bg-white-15 h-12 w-full rounded-[100px] py-3 text-base font-semibold"
      >
        Swap
      </Button>
    </div>
  );
};
