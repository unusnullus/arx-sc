import Image from "next/image";

import { Button } from "@arx/ui/components";
import { PoolTransactions } from "../pool-transactions";

export const HeroSection = () => {
  return (
    <div className="flex items-start justify-between gap-10 py-30">
      <div className="flex items-center flex-1">
        <div className="flex flex-col items-start max-w-[484px] gap-6">
          <div>
            <h1 className="text-[60px] font-semibold flex items-center gap-2 leading-[105%]">
              Buy $ARX token.
            </h1>
            <h1 className="text-[60px] font-semibold text-content-50 leading-[105%]">
              Stake. Govern.
            </h1>
          </div>
          <p className="text-content-70 text-xl">
            ARX is the token that connects users, operators, and builders.
          </p>
          <Button className="bg-primary text-content-100 rounded-[100px] text-base px-6 py-3 h-12 mt-3">
            <Image
              src="/wallet-connect-white.svg"
              width={20}
              height={20}
              alt="Wallet"
              className="size-5"
            />
            <span className="text-base font-semibold">Connect Wallet</span>
          </Button>
        </div>
      </div>
      <div className="flex items-center flex-1">
        <PoolTransactions />
      </div>
    </div>
  );
};
