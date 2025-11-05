"use client";

import Image from "next/image";

import { AlertCircle, Loader2 } from "lucide-react";

import { useDeviceType } from "@arx/ui/hooks";
import { cn } from "@arx/ui/lib";
import { Button } from "@arx/ui/components";

const BUTTON_TEXT = {
  mobile: { connect: "Connect", retry: "Retry" },
  tablet: { connect: "Connect Wallet", retry: "Retry Connection" },
  desktop: { connect: "Connect Wallet", retry: "Retry Connection" },
} as const;

export const WalletButton = ({
  isLoading = false,
  isError = false,
  onClick,
  className,
}: {
  isLoading?: boolean;
  isError?: boolean;
  onClick?: () => void;
  className?: string;
}) => {
  const deviceType = useDeviceType();

  const getButtonText = () => {
    const deviceText = BUTTON_TEXT[deviceType];
    return isError ? deviceText.retry : deviceText.connect;
  };

  if (isLoading) {
    return (
      <Button
        disabled
        variant="outline"
        className={cn(
          "bg-content-100 text-content-black hover:bg-content-100/70 h-12 rounded-[100px] px-6 py-3 text-base",
          className,
        )}
      >
        <div className="flex items-center gap-2">
          <Loader2 className="text-content-black size-7 animate-spin" />
          <span className="text-base-primary font-semibold">Connecting...</span>
        </div>
        <div className="bg-content-black absolute bottom-0 left-0 h-0.5 animate-pulse" />
      </Button>
    );
  }

  if (isError) {
    return (
      <Button
        variant="destructive"
        onClick={onClick}
        className={cn(
          "bg-content-100 text-content-black hover:bg-content-100/70 h-12 rounded-[100px] px-6 py-3 text-base",
          className,
        )}
      >
        <AlertCircle className="text-content-black size-6" />
        <span className="text-content-black font-semibold">
          {getButtonText()}
        </span>
      </Button>
    );
  }

  return (
    <Button
      onClick={onClick}
      className={cn(
        "bg-content-100 text-content-black hover:bg-content-100/70 h-12 rounded-[100px] px-6 py-3 text-base",
        className,
      )}
    >
      <Image
        src="/wallet-connect.svg"
        alt="Wallet Icon"
        className="text-content-black size-5"
        width={24}
        height={24}
        loading="lazy"
      />
      <span className="text-content-black text-sm font-semibold md:text-base">
        {getButtonText()}
      </span>
    </Button>
  );
};
