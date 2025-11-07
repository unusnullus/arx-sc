"use client";

import Image from "next/image";

import { CheckIcon } from "lucide-react";

import { useChain } from "@/entities/chain";
import { cn } from "@arx/ui/lib";
import {
  Badge,
  Button,
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@arx/ui/components";

interface ChainSwitcherProps {
  className?: string;
  variant?: "buttons" | "dropdown" | "minimal";
  showTestnets?: boolean;
  maxVisible?: number;
  onChainChange?: (chainId: number) => void;
}

export const ChainSwitcher = ({
  className,
  variant = "buttons",
  showTestnets = false,
  maxVisible = 3,
  onChainChange,
}: ChainSwitcherProps) => {
  const { chainId, availableChains, switchChain, isSwitching } = useChain({
    showTestnets,
    onChainChange,
  });

  const handleChainSwitch = async (targetChainId: number) => {
    if (targetChainId === chainId) return;
    await switchChain(targetChainId);
  };

  const visibleChains = availableChains.slice(0, maxVisible);
  const hasMoreChains = availableChains.length > maxVisible;

  if (variant === "minimal") {
    return (
      <div className={cn("flex items-center gap-1", className)}>
        {visibleChains.map((chain) => (
          <Tooltip useTouch key={chain.id}>
            <TooltipTrigger asChild>
              <Button
                size="default"
                className={cn(
                  "hover:bg-white-7 border-white-7 h-11 w-11 border p-0",
                  {
                    "bg-white-7": chain.id === chainId,
                  },
                )}
                onClick={() => handleChainSwitch(chain.id)}
                disabled={isSwitching}
                aria-label={`Switch to ${chain.name} network`}
              >
                <div className="relative">
                  <Image
                    src={chain.icon}
                    alt={`${chain.name} network icon`}
                    width={16}
                    height={16}
                    className="h-4 w-4"
                  />
                  {chain.testnet && (
                    <Badge
                      variant="secondary"
                      className="absolute -top-1 -right-1 h-2 w-2 p-0 text-[6px]"
                    >
                      T
                    </Badge>
                  )}
                </div>
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              <div className="flex flex-col gap-1 pb-1">
                <span className="font-medium">{chain.name}</span>
                {chain.testnet && (
                  <Badge variant="outline" className="w-fit text-xs">
                    Testnet
                  </Badge>
                )}
              </div>
            </TooltipContent>
          </Tooltip>
        ))}
        {hasMoreChains && (
          <Tooltip useTouch>
            <TooltipTrigger asChild>
              <Button
                variant="outline"
                size="default"
                className="h-11 w-11 p-0"
                disabled
              >
                <span className="text-xs">
                  +{availableChains.length - maxVisible}
                </span>
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              <p>More chains available</p>
            </TooltipContent>
          </Tooltip>
        )}
      </div>
    );
  }

  if (variant === "dropdown") {
    return (
      <div className={cn("flex flex-wrap gap-2", className)}>
        {visibleChains.map((chain) => (
          <Tooltip useTouch key={chain.id}>
            <TooltipTrigger asChild>
              <Button
                variant={chain.id === chainId ? "default" : "outline"}
                size="default"
                className="h-11 px-3"
                onClick={() => handleChainSwitch(chain.id)}
                disabled={isSwitching}
                aria-label={`Switch to ${chain.name} network${chain.id === chainId ? " (current)" : ""}`}
              >
                <div className="relative">
                  <Image
                    src={chain.icon}
                    alt={`${chain.name} network icon`}
                    width={16}
                    height={16}
                    className="mr-2 h-4 w-4"
                  />
                  {chain.testnet && (
                    <Badge
                      variant="secondary"
                      className="absolute -top-1 -right-1 h-2 w-2 p-0 text-[6px]"
                    >
                      T
                    </Badge>
                  )}
                </div>
                <span className="text-sm">{chain.name}</span>
                {chain.id === chainId && <CheckIcon className="ml-2 h-3 w-3" />}
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              <div className="flex flex-col gap-1">
                <span className="font-medium">{chain.name}</span>
                {chain.testnet && (
                  <Badge variant="outline" className="w-fit text-xs">
                    Testnet
                  </Badge>
                )}
              </div>
            </TooltipContent>
          </Tooltip>
        ))}
        {hasMoreChains && (
          <Tooltip useTouch>
            <TooltipTrigger asChild>
              <Button
                variant="outline"
                size="default"
                className="h-11 px-3"
                disabled
                aria-label={`${availableChains.length - maxVisible} more chains available`}
              >
                <span className="text-sm">
                  +{availableChains.length - maxVisible} more
                </span>
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              <p>More chains available</p>
            </TooltipContent>
          </Tooltip>
        )}
      </div>
    );
  }

  return (
    <div className={cn("flex flex-wrap gap-2", className)}>
      {availableChains.map((chain) => (
        <Tooltip useTouch key={chain.id}>
          <TooltipTrigger asChild>
            <Button
              variant={chain.id === chainId ? "default" : "outline"}
              size="default"
              className="h-11 px-4"
              onClick={() => handleChainSwitch(chain.id)}
              disabled={isSwitching}
              aria-label={`Switch to ${chain.name} network${chain.id === chainId ? " (current)" : ""}`}
            >
              <div className="relative">
                <Image
                  src={chain.icon}
                  alt={`${chain.name} network icon`}
                  width={20}
                  height={20}
                  className="mr-2 h-5 w-5"
                />
                {chain.testnet && (
                  <Badge
                    variant="secondary"
                    className="absolute -top-1 -right-1 h-2 w-2 p-0 text-[6px]"
                  >
                    T
                  </Badge>
                )}
              </div>
              <div className="flex flex-col items-start">
                <span className="text-sm font-medium">{chain.name}</span>
                <span className="text-muted-foreground text-xs">
                  {chain.nativeCurrency.symbol}
                </span>
              </div>
              {chain.id === chainId && <CheckIcon className="ml-2 h-4 w-4" />}
            </Button>
          </TooltipTrigger>
          <TooltipContent>
            <div className="flex flex-col gap-1">
              <span className="font-medium">{chain.name}</span>
              <span className="text-muted-foreground text-sm">
                {chain.nativeCurrency.symbol} • {chain.nativeCurrency.name}
              </span>
              {chain.testnet && (
                <Badge variant="outline" className="w-fit text-xs">
                  Testnet
                </Badge>
              )}
            </div>
          </TooltipContent>
        </Tooltip>
      ))}
    </div>
  );
};
