import Image from "next/image";

import { Button } from "@arx/ui/components";
import { PoolTransactions } from "../pool-transactions";

export const BuySection = () => {
  return (
    <div className="flex items-start justify-between gap-10 py-30">
      <div className="flex flex-1 items-center">
        <div className="flex max-w-[484px] flex-col items-start gap-6">
          <div>
            <h1 className="flex items-center gap-2 text-[60px] leading-[105%] font-semibold">
              Buy $ARX token.
            </h1>
            <h1 className="text-content-50 text-[60px] leading-[105%] font-semibold">
              Stake. Govern.
            </h1>
          </div>
          <p className="text-content-70 text-xl">
            ARX is the token that connects users, operators, and builders.
          </p>
          <Button className="bg-primary text-content-100 mt-3 h-12 rounded-[100px] px-6 py-3 text-base">
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
      <div className="flex flex-1 items-center">
        <PoolTransactions />
      </div>
    </div>
  );
};
