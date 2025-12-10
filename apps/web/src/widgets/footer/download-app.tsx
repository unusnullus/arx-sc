"use client";

import { Button } from "@arx/ui/components";
import { memo, useCallback } from "react";
import { cn } from "@arx/ui/lib";

export const DownloadApp = memo(({ className }: { className?: string }) => {
  const handleDownload = useCallback(() => {
    window.open("https://apps.apple.com/us/app/arx-pro/id6752341948", "_blank");
  }, []);

  return (
    <Button
      className={cn(
        "bg-white-10 hover:bg-white-15 h-13 w-full max-w-[360px] rounded-[100px] px-6 py-3 text-base md:max-w-40",
        className,
      )}
      onClick={handleDownload}
    >
      <span className="text-base font-semibold">Download the App</span>
    </Button>
  );
});

DownloadApp.displayName = "DownloadApp";
