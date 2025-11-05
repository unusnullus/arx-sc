import Image from "next/image";
import Link from "next/link";

import { Button } from "@arx/ui/components";

export const AppHeader = () => {
  return (
    <header className="sticky top-0 z-40 flex w-full items-center justify-between gap-2 px-10 py-5.5 backdrop-blur-md">
      <div className="flex w-full items-center justify-between gap-3">
        <div className="flex w-52 items-center justify-start">
          <Image src="/logo.svg" width={104} height={32} alt="ARX" />
        </div>

        <nav className="flex items-center gap-6">
          <Link href="/">
            <span className="text-content-70 text-base">GitHub</span>
          </Link>
          <Link href="/">
            <span className="text-content-70 text-base">GitBook</span>
          </Link>
          <Link href="/">
            <span className="text-content-70 text-base">Etherscan</span>
          </Link>
          <Link href="/">
            <span className="text-content-70 text-base">CoinMarketCap</span>
          </Link>
        </nav>
        <div className="flex w-52 justify-end">
          <Button className="bg-content-100 text-content-black h-12 rounded-[100px] px-6 py-3 text-base">
            <Image
              src="/wallet-connect.svg"
              width={20}
              height={20}
              alt="Wallet"
              className="text-content-black size-5"
            />
            <span className="text-content-black text-base font-semibold">
              Connect Wallet
            </span>
          </Button>
        </div>
      </div>
    </header>
  );
};
