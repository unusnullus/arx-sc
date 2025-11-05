import Image from "next/image";
import Link from "next/link";

import { ConnectWallet } from "@/features/connect-wallet";

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
          <ConnectWallet />
        </div>
      </div>
    </header>
  );
};
