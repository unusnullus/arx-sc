"use client";

import { Button } from "@arx/ui/components";

export const DownloadButton = () => {
  return (
    <Button
      className="bg-content-100 h-12 w-full max-w-80 rounded-[100px] px-6 py-3 text-base md:max-w-40"
      onClick={() => {
        window.open(
          "https://apps.apple.com/us/app/arx-pro/id6752341948",
          "_blank",
        );
      }}
    >
      <span className="text-content-black text-base font-semibold">
        Download Arx
      </span>
    </Button>
  );
};
