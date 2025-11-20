"use client";

import {
  Button,
  Card,
  CardContent,
  Separator,
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@arx/ui/components";
import { format, setMinutes } from "date-fns";
import { ExternalLink } from "lucide-react";
import Link from "next/link";
import Image from "next/image";
import { useReadContract } from "wagmi";
import { useMemo } from "react";
import { FALLBACK_CHAIN_ID, addressesByChain } from "@arx/config";
import { ARX_TOKEN_SALE_ABI } from "@arx/abi";
import { formatUnits } from "viem";
import { truncateDecimals } from "@arx/ui/lib";

export const TokenInfo = () => {
  const targetChainId = FALLBACK_CHAIN_ID;

  const cfg = useMemo(
    () => addressesByChain[targetChainId] || {},
    [targetChainId],
  );

  const { data: priceUSDC } = useReadContract({
    address: cfg.ARX_TOKEN_SALE as `0x${string}` | undefined,
    abi: ARX_TOKEN_SALE_ABI,
    functionName: "priceUSDC",
    query: {
      enabled: !!cfg.ARX_TOKEN_SALE,
    },
    chainId: targetChainId,
  });

  const formattedPrice = useMemo(() => {
    if (!priceUSDC) return null;

    const pricePerToken = formatUnits(priceUSDC as bigint, 6);
    return truncateDecimals(pricePerToken, 4);
  }, [priceUSDC]);

  return (
    <Card className="bg-white-7 h-fit w-full rounded-[20px] md:rounded-4xl">
      <CardContent className="space-y-6">
        <div className="flex flex-col justify-between sm:flex-row sm:items-center">
          <div className="flex items-center gap-2">
            <span className="text-content-100 text-lg font-semibold lg:text-xl">
              Token Info
            </span>
            <Tooltip useTouch>
              <TooltipTrigger asChild>
                <Link
                  href="https://sepolia.etherscan.io/address/0xA4DDb0963792972C6D832aF6C88F9bd4fe30064D"
                  target="_blank"
                  rel="noopener noreferrer"
                  aria-label="Open token details on Etherscan"
                >
                  <Button
                    variant="ghost"
                    size="icon"
                    aria-label="Open token details on Etherscan"
                  >
                    <ExternalLink className="text-base-secondary size-4" />
                  </Button>
                </Link>
              </TooltipTrigger>
              <TooltipContent>
                <p>Open token details</p>
              </TooltipContent>
            </Tooltip>
          </div>
          <p className="text-content-50 text-sm">
            Price as of{" "}
            {format(setMinutes(new Date(), 0), "HH:mm, dd MMM yyyy")}
          </p>
        </div>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Image
              src={"/tokens/arx-2.svg"}
              alt="ARX"
              width={36}
              height={36}
              priority
              className="size-12 rotate-180 lg:size-14"
            />
            <div className="flex flex-col gap-1">
              <span className="text-content-100 text-lg font-semibold sm:text-xl">
                ARX
              </span>
              <span className="text-content-70 text-base">ERC-20</span>
            </div>
          </div>
          <div className="flex flex-col gap-1">
            <span className="text-content-100 text-lg font-semibold sm:text-xl">
              {formattedPrice ? `$${formattedPrice} / token` : "- / token"}
            </span>
            <span className="text-content-70 text-right text-sm">
              Current market rate
            </span>
          </div>
        </div>
        <Separator />
        <p className="text-content-70 text-base leading-[150%]">
          A native token securing ArxNet — stake, govern, and earn rewards for
          powering private communication and decentralized infrastructure.{" "}
          <br className="hidden md:block" />
          Tail emission declines annually for 10 years and mints only to the
          Rewards Pool; governance can tighten further
        </p>
      </CardContent>
    </Card>
  );
};
