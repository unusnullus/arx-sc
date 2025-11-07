import { TextType } from "@arx/ui/components";
import Image from "next/image";
import { DownloadButton } from "./download-button";
import { BuyArxButton } from "@/features/buy-arx-button";

export const HeroSection = () => {
  return (
    <div className="flex flex-col items-center justify-center gap-12 py-10 md:gap-30 md:py-35">
      <div className="flex flex-col items-center justify-center gap-6 md:gap-8">
        <div className="flex flex-col items-center justify-center">
          <h1 className="flex items-center gap-2 text-[32px] leading-[105%] font-semibold md:text-[80px]">
            The Arx Network.
          </h1>
          <TextType
            className="text-content-50 h-8 text-[32px] leading-[105%] font-semibold md:h-21 md:text-[80px]"
            text={["Encrypted.", "Decentralized.", "Community owned."]}
            typingSpeed={75}
            pauseDuration={1500}
            showCursor={false}
          />
        </div>
        <p className="text-content-70 max-w-[730px] text-center text-lg md:text-xl">
          Arx is a fortress for private communication and money—built on a
          decentralized relay network with an EVM PoS chain. No phones, no
          emails, no Big Tech. Keys live on your device.
        </p>
        <div className="mt-3 flex w-full flex-col items-center justify-center gap-2 md:flex-row md:gap-4">
          <DownloadButton />
          <BuyArxButton />
        </div>
      </div>
      <div className="relative flex w-full items-center justify-center">
        <Image
          src="/images/iphone-hand.svg"
          alt="Arx app on iPhone showing secure messaging interface"
          priority
          width={412}
          height={820}
          className="h-[400px] object-cover md:size-full md:max-h-[892px] md:max-w-[900px] md:object-top"
        />
        <div className="progressive-blur-container">
          <div className="blur-filter" />
          <div className="blur-filter" />
          <div className="blur-filter" />
          <div className="blur-filter" />
          <div className="blur-filter" />
          <div className="blur-filter" />
          <div className="blur-filter" />
          <div className="gradient" />
        </div>
      </div>
    </div>
  );
};
