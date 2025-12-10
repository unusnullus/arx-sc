"use client";

import { Button } from "@arx/ui/components";
import { memo, useCallback } from "react";
import { cn } from "@arx/ui/lib";

export const BuyArxButton = memo(({ className }: { className?: string }) => {
  const handleBuy = useCallback(() => {
    document
      .getElementById("buy")
      ?.scrollIntoView({ behavior: "smooth", block: "center" });
  }, []);

  return (
    <Button
      className={cn(
        "bg-white-10 hover:bg-white-15 h-13 w-full max-w-[337px] rounded-[100px] px-6 py-3 text-base md:max-w-40",
        className,
      )}
      onClick={handleBuy}
    >
      <span className="text-base font-semibold">Buy $ARX</span>
    </Button>
  );
});

BuyArxButton.displayName = "BuyArxButton";
