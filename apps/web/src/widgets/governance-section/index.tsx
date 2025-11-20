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
    <div className="flex flex-col items-center gap-6 px-4 py-10 md:px-0 md:py-30">
      <div className="flex flex-col items-center">
        <h1 className="flex items-center gap-2 text-[38px] leading-[105%] font-semibold md:text-[60px]">
          Stake and govern
        </h1>
        <h1 className="text-content-50 text-[38px] leading-[105%] font-semibold md:text-[60px]">
          the network
        </h1>
      </div>
      <p className="text-t-secondary text-center text-lg md:text-xl">
        Stake ARX to earn rewards, run nodes, and take part in shaping network
        parameters.
      </p>
      <div className="mt-4 flex w-full flex-col items-center justify-between gap-12 md:mt-30 md:mb-25 lg:flex-row">
        {cards.map((card, index) => (
          <Fragment key={card.title}>
            <div className="flex flex-col gap-3">
              <span className="text-content-70 text-base">{card.title}</span>
              <div className="flex items-center gap-4">
                <span className="text-content-100 text-3xl md:text-4xl md:font-semibold">
                  ≥{card.number}
                </span>
                <DotBar progress={card.progress} />
              </div>
            </div>
            {index < cards.length - 1 && (
              <>
                <div className="hidden h-28 w-1 md:block">
                  <Separator orientation="vertical" className="h-16" />
                </div>
                <div className="block w-full md:hidden">
                  <Separator />
                </div>
              </>
            )}
          </Fragment>
        ))}
      </div>

      <div className="mt-10 w-full max-w-[920px] rounded-[20px] bg-gradient-to-r from-[#6C6FB460] via-[#42457B00] via-75% to-[#42457B] p-[1px] opacity-80 md:mt-32 md:rounded-4xl">
        <Card className="radial w-full">
          <div className="flex flex-col-reverse items-center justify-between gap-6 px-5 py-4 md:flex-row md:gap-12 md:px-14 md:py-8">
            <div className="flex flex-1 flex-col gap-4">
              <div className="flex flex-col">
                <h2 className="text-center text-[38px] leading-[105%] font-semibold md:text-start md:text-[60px]">
                  Sustainable
                </h2>
                <h2 className="text-purple-gradient text-center text-[38px] leading-[105%] font-semibold md:text-start md:text-[60px]">
                  by design
                </h2>
              </div>
              <p className="text-content-70 max-w-xl text-center text-base md:text-start">
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
                className="size-50 md:size-69"
                aria-label="Animation of ARX coin"
              />
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
};
