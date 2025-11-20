import Image from "next/image";
import Link from "next/link";
import { DownloadApp } from "./download-app";

export const Footer = () => {
  return (
    <footer className="flex flex-col gap-8 px-4 py-20 md:gap-12 md:px-0">
      <div className="flex flex-col justify-between gap-8 md:flex-row">
        <div className="flex flex-1 items-center justify-between gap-12 md:grow-2 md:flex-col md:items-start md:justify-start">
          <Link href="/" className="cursor-pointer">
            <Image
              src="/logo.svg"
              alt="ARX"
              width={104}
              height={32}
              className="h-6 w-auto md:h-auto"
            />
          </Link>
          <Link
            href="https://apps.apple.com/us/app/arx-pro/id6752341948"
            target="_blank"
            className="cursor-pointer"
            aria-label="Download Arx app from App Store"
          >
            <Image
              src="/images/qr.svg"
              alt="QR code to download Arx app"
              width={200}
              height={200}
              className="hidden h-50 w-50 md:block"
            />
          </Link>
          <span className="text-content-100 block text-xs md:hidden">
            © 2025 All rights reserved.
          </span>
        </div>
        <div className="flex justify-center md:hidden">
          <DownloadApp />
        </div>
        <div className="flex flex-1 grow-3 flex-col gap-15">
          <div className="flex justify-between gap-8">
            <div className="flex flex-1 flex-col gap-5">
              <span className="text-content-100 text-base md:text-lg">
                Resources
              </span>
              {[
                {
                  href: "https://www.arx.pro/",
                  label: "Arx.Pro",
                  target: "_blank",
                },
                {
                  href: "https://sepolia.etherscan.io/address/0x45B19ac7E4fDC7428a206482E94267EC7baA1221",
                  label: "Etherscan",
                  target: "_blank",
                },
                {
                  href: "https://github.com/unusnullus/arx-sc",
                  label: "GitHub",
                  target: "_blank",
                },
                {
                  href: "https://docs.arx.pro/",
                  label: "Documentation",
                  target: "_blank",
                },
              ].map(({ href, label, target }) => (
                <Link
                  href={href}
                  target={target}
                  key={label}
                  className="cursor-pointer"
                >
                  <span className="text-content-70 hover:text-content-100 cursor-pointer text-[15px] transition-all duration-300 md:text-lg">
                    {label}
                  </span>
                </Link>
              ))}
            </div>
            <div className="flex flex-1 flex-col gap-5">
              <span className="text-content-100 text-base md:text-lg">
                Social networks
              </span>
              {["Telegram", "Facebook", "LinkedIn", "X.com"].map((item) => (
                <span
                  key={item}
                  className="text-content-70 hover:text-content-100 cursor-pointer text-[15px] transition-all duration-300 md:text-lg"
                >
                  {item}
                </span>
              ))}
            </div>
          </div>
          <div>
            <span className="text-content-70 text-xs">
              Arx – private network for messaging, payments, and connectivity.
              Holding or using $ARX does not constitute an investment contract
              or a promise of future value. $ARX is a utility token used for
              governance, staking, and network operations.
            </span>
          </div>
        </div>
      </div>
      <div className="border-white-10 flex justify-between gap-8 border-t pt-8 md:pt-12">
        <div className="hidden flex-1 grow-2 md:flex">
          <span className="text-content-100 text-xs">
            © 2025 All rights reserved.
          </span>
        </div>
        <div className="flex flex-1 justify-between gap-2 md:grow-3 md:justify-start md:gap-12">
          {["Terms of Service", "Privacy Policy"].map((item) => (
            <span
              key={item}
              className="text-content-70 hover:text-content-100 cursor-pointer text-xs underline transition-all duration-300"
            >
              {item}
            </span>
          ))}
        </div>
      </div>
    </footer>
  );
};
