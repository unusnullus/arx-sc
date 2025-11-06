"use client";

import { Button } from "@arx/ui/components";
import { memo, useCallback } from "react";

export const BuyArxButton = memo(() => {
  const handleBuy = useCallback(() => {
    document.getElementById("buy")?.scrollIntoView({ behavior: "smooth" });
  }, []);

  return (
    <Button
      className="bg-white-10 h-12 w-full max-w-80 rounded-[100px] px-6 py-3 text-base md:max-w-40"
      onClick={handleBuy}
    >
      <span className="text-base font-semibold">Buy $ARX</span>
    </Button>
  );
});
