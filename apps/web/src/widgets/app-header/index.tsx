import Image from "next/image";
import Link from "next/link";

import { Button } from "@arx/ui/components";

export const AppHeader = () => {
  return (
    <header className="sticky top-0 z-40 flex items-center justify-between gap-2 px-10 py-5.5 w-full">
      <div className="flex items-center justify-between gap-3 w-full">
        <div className="w-52 flex items-center justify-start">
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
        <div className="w-52 flex justify-end">
          <Button className="bg-content-100 text-content-black rounded-[100px] text-base px-6 py-3 h-12">
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
    </header>
  );
};
