"use client";

import { Fragment } from "react";
import { Separator, Card, DotBar } from "@arx/ui/components";

const cards = [
  { title: "Delegate", number: "25k", progress: 0.25 },
  { title: "Validator", number: "100k", progress: 0.45 },
  { title: "Block Producer", number: "250k", progress: 1 },
];

export const GovernanceSection = () => {
  return (
    <div className="flex flex-col items-center py-30 gap-6">
      <div className="flex flex-col items-center">
        <h1 className="text-[60px] font-semibold flex items-center gap-2 leading-[105%]">
          Stake and govern
        </h1>
        <h1 className="text-[60px] font-semibold text-content-50 leading-[105%]">
          the network
        </h1>
      </div>
      <p className="text-center text-t-secondary text-lg">
        Stake ARX to earn rewards, run nodes, and take part in shaping network
        parameters.
      </p>
      <div className="flex items-center justify-between w-full gap-12 mt-30 mb-25">
        {cards.map((card, index) => (
          <Fragment key={card.title}>
            <div className="flex flex-col gap-3">
              <span className="text-t-secondary text-base">{card.title}</span>
              <div className="flex items-center gap-4">
                <span className="text-foreground text-4xl font-semibold">
                  ≥{card.number}
                </span>
                <DotBar progress={card.progress} />
              </div>
            </div>
            {index < cards.length - 1 && (
              <div className="hidden md:block h-28 w-1">
                <Separator orientation="vertical" className="h-16" />
              </div>
            )}
          </Fragment>
        ))}
      </div>

      <div className="mt-32 w-full max-w-[920px] p-[1px] rounded-4xl bg-gradient-to-r from-[#6C6FB4] via-[#42457B00] via-70% to-[#42457B]">
        <Card className="w-full bg-background">
          <div className="flex items-center justify-between gap-12 px-14 py-8">
            <div className="flex flex-col gap-4 flex-1">
              <div className="flex flex-col">
                <h2 className="text-[60px] font-semibold leading-[105%]">
                  Sustainable
                </h2>
                <h2 className="text-[60px] font-semibold text-purple-gradient leading-[105%]">
                  by design
                </h2>
              </div>
              <p className="text-content-70 text-lg max-w-xl">
                Network revenue from Pro, Teams, VPN, and eSIM services supports
                buy-back and burn. Tail emission declines over 10 years, minting
                only to the Rewards Pool.
              </p>
            </div>
            <div className="flex-shrink-0">
              <video
                src="/videos/coin.mp4"
                autoPlay
                loop
                muted
                playsInline
                className="size-69"
              />
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
};
