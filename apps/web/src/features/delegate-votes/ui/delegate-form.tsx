"use client";

import { useState, useCallback } from "react";
import { useAccount } from "wagmi";
import { isAddress } from "viem";

import { Button, Input, Spinner, toast } from "@arx/ui/components";
import { useDelegation } from "@/entities/governance";
import { cn } from "@arx/ui/lib";

export const DelegateForm = () => {
  const { address } = useAccount();
  const { delegate, isDelegating } = useDelegation();
  const [delegateeAddress, setDelegateeAddress] = useState<string>(
    address || "",
  );

  const handleDelegate = useCallback(async () => {
    if (!delegateeAddress) {
      toast.error("Please enter a delegatee address");
      return;
    }

    if (!isAddress(delegateeAddress)) {
      toast.error("Invalid address format");
      return;
    }

    try {
      await delegate(delegateeAddress as `0x${string}`);
      toast.success("Delegation successful");
    } catch (error) {
      console.error("Delegation failed:", error);
    }
  }, [delegateeAddress, delegate]);

  const handleDelegateToSelf = useCallback(async () => {
    if (!address) {
      toast.error("Wallet not connected");
      return;
    }

    try {
      await delegate(address);
      toast.success("Delegated to yourself");
    } catch (error) {
      console.error("Delegation failed:", error);
    }
  }, [address, delegate]);

  const isInvalidAddress = !!delegateeAddress && !isAddress(delegateeAddress);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-2">
        <label className="text-content-70 text-sm font-medium">
          Delegatee Address
        </label>
        <Input
          type="text"
          placeholder="0x..."
          value={delegateeAddress}
          onChange={(e) => setDelegateeAddress(e.target.value)}
          disabled={isDelegating}
          aria-invalid={isInvalidAddress}
          className={cn(
            `text-content-100 placeholder:text-content-70 bg-content-black rounded-lg p-0 px-4 shadow-none focus-visible:ring-0 md:text-base`,
            {
              "text-red-500": isInvalidAddress,
              "cursor-not-allowed opacity-50": isDelegating,
            },
          )}
        />
        {isInvalidAddress && (
          <p className="text-error text-sm">Invalid address format</p>
        )}
      </div>

      <div className="flex w-full gap-2">
        <Button
          onClick={handleDelegate}
          disabled={isDelegating || !delegateeAddress || isInvalidAddress}
          className="text-content-100 bg-white-10 hover:bg-white-15 h-12 flex-1 rounded-[100px] py-3 text-base font-semibold"
        >
          {isDelegating ? (
            <div className="flex items-center gap-2">
              Delegating
              <Spinner variant="ellipsis" size={16} />
            </div>
          ) : (
            "Delegate"
          )}
        </Button>
        <Button
          onClick={handleDelegateToSelf}
          disabled={isDelegating || !address}
          className="bg-content-100 text-content-black h-12 flex-1 rounded-[100px] px-6 py-3 text-base hover:bg-[#E0D0FF] md:max-w-40"
        >
          Delegate to Self
        </Button>
      </div>
    </div>
  );
};
