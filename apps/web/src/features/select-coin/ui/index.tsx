"use client";

import { memo, useCallback, useState } from "react";

import Image from "next/image";

import { useAccount } from "wagmi";

import { FALLBACK_CHAIN_ID, type Token, getTokensByChainId } from "@arx/config";
import { cn } from "@arx/ui/lib";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@arx/ui/components";

import { SelectCoinItem } from "./select-coin-item";
import { useConnectionCheck } from "@/entities/wallet";

export const SelectCoinBase = ({
  tokens,
  onSelect,
  triggerClassName,
}: {
  tokens?: Token[];
  onSelect?: (token: Token) => void;
  triggerClassName?: string;
}) => {
  const { chainId } = useAccount();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;

  const { checkConnection, address: userAddress } = useConnectionCheck();

  const [selectedToken, setSelectedToken] = useState<Token>(
    tokens?.[0] ?? getTokensByChainId(targetChainId)[0],
  );
  const [open, setOpen] = useState(false);

  const handleSelect = useCallback(
    (token: Token) => {
      setSelectedToken(token);
      onSelect?.(token);
    },
    [onSelect],
  );

  const handleValueChange = useCallback(
    (value: string) => {
      const token = tokens?.find((t) => t.address === value);
      if (token) handleSelect(token);
    },
    [tokens, handleSelect],
  );

  const handleOpenChange = useCallback(
    (value: boolean) => {
      if (!checkConnection()) return;

      setOpen(value);
    },
    [checkConnection],
  );

  return (
    <Select
      value={selectedToken?.address ?? ""}
      onValueChange={handleValueChange}
      open={open}
      onOpenChange={handleOpenChange}
    >
      <SelectTrigger
        className={cn(
          "w-fit cursor-pointer border-none p-0 shadow-none focus-visible:border-none focus-visible:ring-0",
          triggerClassName,
        )}
        aria-label={`Selected token: ${selectedToken?.name} (${selectedToken?.symbol})`}
      >
        <SelectValue>
          <div className="flex items-center gap-2">
            <Image
              src={selectedToken?.logoURI}
              alt={`${selectedToken?.name} token logo`}
              width={36}
              height={36}
              className="size-6 sm:size-7 md:size-8 lg:size-9"
              priority
              fetchPriority="high"
              role="img"
              aria-hidden="false"
            />
            <span
              className="text-base-primary text-base font-semibold lg:text-lg"
              aria-label={`Token symbol: ${selectedToken?.symbol}`}
            >
              {selectedToken?.symbol}
            </span>
          </div>
        </SelectValue>
      </SelectTrigger>
      <SelectContent
        className="bg-content-grey w-[300px] rounded-2xl border-none"
        role="listbox"
        aria-label="Select token"
      >
        {tokens?.map((token) => (
          <SelectItem
            key={token.address}
            value={token.address}
            className={cn("hover:bg-white-7 rounded-2xl", {
              "bg-white-7": token.address === selectedToken?.address,
            })}
            role="option"
            aria-selected={token.address === selectedToken?.address}
          >
            <SelectCoinItem
              tokenAddress={token?.address}
              userAddress={userAddress}
            />
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
};

export const SelectCoin = memo(SelectCoinBase);
