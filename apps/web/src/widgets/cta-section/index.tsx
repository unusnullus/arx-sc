import { Aurora } from "@arx/ui/components";
import { ConnectWallet } from "@/features/connect-wallet";
import { BuyArxButton } from "@/features/buy-arx-button";

export const CtaSection = () => {
  return (
    <div className="bg-white-5 relative flex w-full flex-col items-center gap-10 overflow-hidden rounded-4xl px-6 py-25 md:gap-25 md:px-10 md:py-46">
      <Aurora
        colorStops={[
          "#9130cb",
          "#d84ff2",
          "#6820ea",

          // "#8336d9",
          // "#a337dc",
          // "#ce49f1",
          // "#fb9488",
          // "#a28cff",
          // "#ff74d4",
          // "#ffb8de",
          // "#f98549",
          // "#ffdde1",
        ]}
        blend={0.3}
        amplitude={0.5}
        speed={1}
        className="absolute top-0 left-0 z-0 h-full w-full rotate-180"
      />
      <div className="z-10 flex flex-col items-center gap-6 text-center">
        <h1 className="flex items-center gap-2 text-[32px] leading-[105%] font-semibold md:text-[60px]">
          Help steer the network
          <br className="hidden md:block" />
          you use
        </h1>
        <h1 className="text-content-70 text-xl leading-[150%]">
          Buy $ARX to vote, stake, and unlock operator roles.{" "}
          <br className="hidden md:block" />
          Your conversations and their reliability should belong to you, not Big
          Tech.
        </h1>
        <div className="flex flex-col items-center gap-2 md:flex-row">
          <BuyArxButton className="w-50 md:max-w-50" />
          <ConnectWallet idle className="w-50" />
        </div>
      </div>
    </div>
  );
};
