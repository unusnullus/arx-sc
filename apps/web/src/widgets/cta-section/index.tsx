import { Aurora } from "@arx/ui/components";
import { ConnectWallet } from "@/features/connect-wallet";

export const CtaSection = () => {
  return (
    <div className="bg-white-5 relative flex w-full flex-col items-center gap-10 overflow-hidden rounded-4xl px-6 py-25 md:gap-25 md:px-10 md:py-46">
      <Aurora
        colorStops={[
          "#6541ff",
          "#a28cff",
          "#ff74d4",
          "#ffb8de",
          "#ef697e",
          "#f98549",
          "#ffdde1",
        ]}
        blend={0.5}
        amplitude={0.7}
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
        <ConnectWallet idle />
      </div>
    </div>
  );
};
