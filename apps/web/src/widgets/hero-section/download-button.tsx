"use client";

import { Button } from "@arx/ui/components";
import { memo, useCallback } from "react";

export const DownloadButton = memo(() => {
  const handleDownload = useCallback(() => {
    window.open("https://apps.apple.com/us/app/arx-pro/id6752341948", "_blank");
  }, []);

  return (
    <Button
      className="bg-content-100 h-12 w-full max-w-80 rounded-[100px] px-6 py-3 text-base hover:bg-[#E0D0FF] md:max-w-40"
      onClick={handleDownload}
    >
      <span className="text-content-black text-base font-semibold">
        Download Arx
      </span>
    </Button>
  );
});

DownloadButton.displayName = "DownloadButton";
