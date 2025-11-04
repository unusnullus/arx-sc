import Image from "next/image";

import { Button } from "@arx/ui/components";

export const CtaSection = () => {
  return (
    <div className="flex flex-col items-center py-30 gap-25 relative">
      <div className="flex flex-col items-center text-center gap-6">
        <h1 className="text-[60px] font-semibold flex items-center gap-2 leading-[105%]">
          Help steer the network
          <br />
          you use
        </h1>
        <h1 className="text-xl text-content-70 leading-[150%]">
          Buy $ARX to vote, stake, and unlock operator roles. <br />
          Your conversations and their reliability should belong to you, not Big
          Tech.
        </h1>
        <Button className="bg-content-100 text-content-black rounded-[100px] text-base px-6 py-3 h-12 mt-4">
          <Image
            src="/wallet-connect.svg"
            width={20}
            height={20}
            alt="Wallet"
            className="size-5 text-content-black"
          />
          <span className="text-content-black text-base font-semibold">
            Connect Wallet
          </span>
        </Button>
      </div>
    </div>
  );
};
