import { Button, TextType } from "@arx/ui/components";
import Image from "next/image";
import { DownloadButton } from "./download-button";

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
          <Button className="bg-white-10 h-12 w-full max-w-80 rounded-[100px] px-6 py-3 text-base md:max-w-40">
            <span className="text-base font-semibold">Buy $ARX</span>
          </Button>
        </div>
      </div>
      <div className="relative flex w-full items-center justify-center">
        <Image
          src="/images/iphone-hand.svg"
          alt="Iphone Hand"
          width={412}
          height={820}
          className="h-[400px] object-cover md:size-full md:max-h-[892px] md:max-w-[900px] md:object-top"
        />
        <div className="absolute inset-x-0 bottom-0 z-0 h-1/2 mask-t-from-40% backdrop-blur-sm" />
        <div className="absolute inset-x-0 bottom-0 z-10 h-1/3 bg-gradient-to-t from-black to-black/0" />
      </div>
    </div>
  );
};
