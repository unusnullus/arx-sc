import { Button, TextType } from "@arx/ui/components";
import Image from "next/image";

export const HeroSection = () => {
  return (
    <div className="flex flex-col items-center justify-center gap-30 py-35">
      <div className="flex flex-col items-center justify-center gap-8">
        <div className="flex flex-col items-center justify-center">
          <h1 className="flex items-center gap-2 text-[80px] leading-[105%] font-semibold">
            The Arx Network.
          </h1>
          <TextType
            className="text-content-50 h-21 text-[80px] leading-[105%] font-semibold"
            text={["Encrypted.", "Decentralized.", "Community owned."]}
            typingSpeed={75}
            pauseDuration={1500}
            showCursor={false}
          />
        </div>
        <p className="text-content-70 max-w-[730px] text-center text-xl">
          Arx is a fortress for private communication and money—built on a
          decentralized relay network with an EVM PoS chain. No phones, no
          emails, no Big Tech. Keys live on your device.
        </p>
        <div className="flex items-center justify-center gap-4">
          <Button className="bg-content-100 mt-3 h-12 w-full max-w-40 rounded-[100px] px-6 py-3 text-base">
            <span className="text-content-black text-base font-semibold">
              Download Arx
            </span>
          </Button>
          <Button className="bg-white-10 mt-3 h-12 w-full max-w-40 rounded-[100px] px-6 py-3 text-base">
            <span className="text-base font-semibold">Buy $ARX</span>
          </Button>
        </div>
      </div>
      <div className="relative">
        <Image
          src="/images/iphone-hand.svg"
          alt="Iphone Hand"
          width={412}
          height={820}
          className="size-full max-h-[892px] max-w-[900px] object-top"
        />
        <div className="absolute inset-x-0 bottom-0 z-0 h-1/2 mask-t-from-40% backdrop-blur-sm" />
        <div className="absolute inset-x-0 bottom-0 z-10 h-1/3 bg-gradient-to-t from-black to-black/0" />
      </div>
    </div>
  );
};
