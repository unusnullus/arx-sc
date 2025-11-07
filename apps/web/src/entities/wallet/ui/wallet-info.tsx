"use client";

import { useCallback, useState } from "react";

import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";

import {
  CheckCircle,
  ChevronDown,
  Copy,
  ExternalLink,
  LogOut,
} from "lucide-react";

import { ChainSwitcher, useChain } from "@/entities/chain";
import { useDeviceType } from "@arx/ui/hooks";
import { cn } from "@arx/ui/lib";
import {
  Button,
  Popover,
  PopoverContent,
  PopoverTrigger,
  Skeleton,
  toast,
} from "@arx/ui/components";

import { useWalletBalance } from "../hooks";

export const WalletInfo = ({
  address,
  onDisconnect,
  className,
}: {
  address: string;
  onDisconnect?: () => void;
  className?: string;
}) => {
  const router = useRouter();
  const [copiedAddress, setCopiedAddress] = useState(false);
  const [popoverOpen, setPopoverOpen] = useState(false);
  const deviceType = useDeviceType();
  const { currentChain } = useChain();
  const {
    formattedBalance,
    symbol,
    isLoading: isBalanceLoading,
  } = useWalletBalance();

  const handleCopyAddress = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(address);
      setCopiedAddress(true);
      toast.success("Address copied to clipboard");
      setTimeout(() => setCopiedAddress(false), 2000);
    } catch {
      toast.error("Failed to copy address");
    }
  }, [address]);

  const handleDisconnect = useCallback(() => {
    onDisconnect?.();

    setPopoverOpen(false);
    router.push("/");
  }, [onDisconnect, router]);

  const formattedAddress =
    deviceType === "mobile"
      ? `${address.slice(0, 3)}...${address.slice(-3)}`
      : `${address.slice(0, 6)}...${address.slice(-4)}`;

  return (
    <div className={cn("flex items-center gap-2", className)}>
      <Popover open={popoverOpen} onOpenChange={setPopoverOpen}>
        <PopoverTrigger asChild>
          <Button
            className={cn(
              "bg-white-10 hover:bg-white-15 text-content-100 h-12 rounded-[100px] px-6 py-3 text-base",
            )}
            aria-label={`Connected wallet: ${formattedAddress}`}
            aria-haspopup="dialog"
            aria-expanded={popoverOpen}
          >
            <div className="flex items-center gap-2">
              {currentChain && (
                <Image
                  src={currentChain.icon}
                  alt={`${currentChain.name} network icon`}
                  className="size-6"
                  width={20}
                  height={20}
                  role="img"
                  aria-hidden="false"
                />
              )}
              <span
                className="text-base font-semibold"
                aria-label={`Wallet address: ${address}`}
              >
                {formattedAddress}
              </span>
              <ChevronDown
                className={cn("h-3 w-3 transition-transform", {
                  "rotate-180": popoverOpen,
                })}
                aria-hidden="true"
              />
            </div>
          </Button>
        </PopoverTrigger>

        <PopoverContent
          className="w-fit p-3 md:p-4"
          align="center"
          role="dialog"
          aria-labelledby="wallet-info-title"
        >
          <div className="space-y-4">
            <div className="space-y-3">
              <div className="flex items-center gap-2">
                <div className="flex-1">
                  <h3
                    id="wallet-info-title"
                    className="text-content-70 text-sm font-medium md:text-base"
                  >
                    Connected wallet
                  </h3>
                  <p
                    className="text-muted-foreground font-mono text-xs md:text-sm"
                    aria-label={`Full wallet address: ${address}`}
                  >
                    {address}
                  </p>
                </div>
              </div>

              <div className="space-y-3">
                <div>
                  <p className="text-muted-foreground mb-2 text-xs font-medium">
                    Network
                  </p>
                  <ChainSwitcher
                    variant="minimal"
                    className="justify-start"
                    maxVisible={3}
                  />
                </div>

                {currentChain && (
                  <div
                    className="bg-white-7 flex items-center gap-2 rounded-lg p-2"
                    role="region"
                    aria-label="Current network information"
                  >
                    <Image
                      src={currentChain.icon}
                      alt={`${currentChain.name} network icon`}
                      className="size-8"
                      width={20}
                      height={20}
                      role="img"
                      aria-hidden="false"
                    />
                    <div className="flex-1">
                      <p className="text-sm font-medium md:text-base">
                        {currentChain.name}
                      </p>
                      <p className="text-content-70 text-xs md:text-sm">
                        {currentChain.nativeCurrency.symbol} •{" "}
                        {currentChain.nativeCurrency.name}
                      </p>
                    </div>
                  </div>
                )}
              </div>

              <div
                className="bg-white-7 rounded-lg p-2"
                role="region"
                aria-label="Wallet balance"
              >
                <p className="text-content-70 mb-1 text-xs md:text-sm">
                  Balance
                </p>
                <div className="flex items-center gap-2">
                  {isBalanceLoading ? (
                    <Skeleton
                      className="h-4 w-16"
                      aria-label="Loading balance"
                      role="status"
                    />
                  ) : (
                    <p
                      className="text-content-100 text-base font-semibold"
                      aria-label={`Balance: ${formattedBalance} ${symbol}`}
                    >
                      {formattedBalance} {symbol}
                    </p>
                  )}
                </div>
              </div>
            </div>

            <div className="border-white-10 mb-2 flex flex-col items-center gap-2 border-t pt-2 md:flex-row">
              <Button
                variant="ghost"
                size="default"
                onClick={handleCopyAddress}
                className="hover:bg-white-7 h-11 w-full min-w-48 flex-1 rounded-4xl"
                aria-label={
                  copiedAddress
                    ? "Address copied to clipboard"
                    : "Copy wallet address to clipboard"
                }
              >
                {copiedAddress ? (
                  <CheckCircle
                    className="h-4 w-4 text-green-500"
                    aria-hidden="true"
                  />
                ) : (
                  <Copy
                    className="text-content-70 h-4 w-4"
                    aria-hidden="true"
                  />
                )}
                <span className="text-content-70 text-base">
                  {copiedAddress ? "Copied" : "Copy wallet address"}
                </span>
              </Button>

              <Link
                href={`https://etherscan.io/address/${address}`}
                target="_blank"
                rel="noopener noreferrer"
                aria-label="View wallet on Etherscan explorer"
              >
                <Button
                  variant="ghost"
                  size="default"
                  className="hover:bg-white-7 h-11 w-full flex-1 rounded-4xl"
                >
                  <ExternalLink
                    className="text-content-70 h-4 w-4"
                    aria-hidden="true"
                  />
                  <span className="text-content-70 text-base">Explorer</span>
                </Button>
              </Link>
            </div>

            <div className="border-white-10 flex items-center gap-2 border-t pt-4 md:pt-2">
              <Button
                variant="destructive"
                size="default"
                onClick={handleDisconnect}
                className="h-11 flex-1 rounded-4xl text-base"
                aria-label="Disconnect wallet"
              >
                <LogOut className="mr-1 h-3 w-3" aria-hidden="true" />
                Disconnect
              </Button>
            </div>
          </div>
        </PopoverContent>
      </Popover>
    </div>
  );
};
