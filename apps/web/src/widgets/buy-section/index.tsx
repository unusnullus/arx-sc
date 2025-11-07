import { PoolTransactions } from "../pool-transactions";
import { ConnectWallet } from "@/features/connect-wallet";

export const BuySection = () => {
  return (
    <div
      id="buy"
      className="flex flex-col items-center justify-between gap-10 md:flex-row md:items-stretch md:gap-10 md:py-30"
    >
      <div className="flex flex-1 items-center">
        <div className="flex max-w-[484px] flex-col items-center gap-6 md:items-start">
          <div className="flex flex-col items-center md:items-start">
            <h1 className="flex items-center gap-2 text-[32px] leading-[105%] font-semibold md:text-[60px]">
              Buy $ARX token.
            </h1>
            <h1 className="text-content-50 text-[32px] leading-[105%] font-semibold md:text-[60px]">
              Stake. Govern.
            </h1>
          </div>
          <p className="text-content-70 text-center text-lg md:text-left md:text-xl">
            ARX is the token that connects users, operators, and builders.
          </p>
          <ConnectWallet idle className="w-full md:w-auto" device="desktop" />
        </div>
      </div>
      <div className="flex w-full flex-1 items-center">
        <PoolTransactions />
      </div>
    </div>
  );
};
