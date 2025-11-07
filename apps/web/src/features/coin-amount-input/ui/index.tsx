"use client";

import { useEffect, useState } from "react";

import { useAccount, useBalance } from "wagmi";

import { useMounted } from "@arx/ui/hooks";
import { parseUnits } from "viem";
import { Input } from "@arx/ui/components";
import { cn } from "@arx/ui/lib";
import { isNativeToken, Token } from "@arx/config";

interface CoinAmountInputProps {
  token: Token;
  value?: string;
  onChange?: (value: string) => void;
  placeholder?: string;
  className?: string;
  balance?: bigint;
  disabled?: boolean;
}

export const CoinAmountInput = ({
  token,
  value = "",
  onChange,
  placeholder = "0.0",
  className,
  balance: userTokenBalance,
  disabled = false,
}: CoinAmountInputProps) => {
  const mounted = useMounted();
  const { address: userAddress } = useAccount();
  const [inputValue, setInputValue] = useState(value);
  const [isValid, setIsValid] = useState(true);

  const { data: balance, isLoading } = useBalance({
    address: userAddress,
    ...(!isNativeToken(token.address) && { token: token.address }),
    query: {
      enabled: mounted && !!userAddress && !userTokenBalance,
    },
  });

  useEffect(() => {
    setInputValue(value);
  }, [value]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const rawValue = e.target.value;

    if (rawValue === "") {
      setInputValue("");
      onChange?.("");
      setIsValid(true);
      return;
    }

    const decimalPattern = new RegExp(`^\\d*(\\.\\d{0,18})?$`);
    if (!decimalPattern.test(rawValue)) {
      return;
    }

    if (balance && rawValue !== "") {
      try {
        const inputAmount = parseUnits(rawValue, token.decimals);
        const userBalance = userTokenBalance || balance?.value;

        if (inputAmount > userBalance) {
          setIsValid(false);
        } else {
          setIsValid(true);
        }
      } catch {
        setIsValid(false);
      }
    }

    setInputValue(rawValue);
    onChange?.(rawValue);
  };

  return (
    <Input
      type="text"
      inputMode="decimal"
      value={inputValue}
      disabled={disabled || isLoading || !userAddress}
      onChange={handleInputChange}
      placeholder={placeholder}
      className={cn(
        `text-content-100 placeholder:text-content-70 border-none bg-transparent p-0 text-right text-lg shadow-none placeholder:text-lg focus-visible:ring-0 md:text-base lg:text-lg`,
        {
          "text-red-500": !isValid,
          "cursor-not-allowed opacity-50": disabled || isLoading,
        },
        className,
      )}
    />
  );
};
