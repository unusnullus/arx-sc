"use client";

import { useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { Menu, ChevronRight } from "lucide-react";

import { ConnectWallet } from "@/features/connect-wallet";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTrigger,
} from "@arx/ui/components";

export const AppHeader = () => {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const navLinks = [
    {
      href: "https://github.com/unusnullus/arx-sc",
      label: "GitHub",
      target: "_blank",
    },
    { href: "https://docs.arx.pro/", label: "Documentation", target: "_blank" },
    { href: "/", label: "Etherscan", target: "_blank" },
    { href: "/", label: "CoinMarketCap", target: "_blank" },
  ];

  return (
    <header className="sticky top-0 z-40 flex w-full items-center justify-between gap-2 px-4 py-4 backdrop-blur-md md:px-6 md:py-5 lg:px-10 lg:py-5.5">
      <div className="flex w-full items-center justify-between gap-3">
        <div className="flex items-center justify-start md:w-52">
          <Link href="/" className="cursor-pointer" target="_blank">
            <Image
              src="/logo.svg"
              width={104}
              height={32}
              alt="ARX"
              className="h-6 w-auto md:h-8"
            />
          </Link>
        </div>

        <nav className="hidden items-center gap-6 lg:flex">
          {navLinks.map((link) => (
            <Link
              key={link.label}
              href={link.href}
              target={link.target}
              className="text-content-70 hover:text-content-100 cursor-pointer text-base transition-all duration-300"
            >
              <span> {link.label}</span>
            </Link>
          ))}
        </nav>

        <div className="flex items-center gap-3 md:gap-4">
          <div className="flex justify-end lg:w-52">
            <ConnectWallet />
          </div>
          <Sheet open={mobileMenuOpen} onOpenChange={setMobileMenuOpen}>
            <SheetTrigger asChild>
              <button
                className="text-content-100 transition-colors lg:hidden"
                aria-label="Toggle menu"
              >
                <Menu className="h-6 w-6" />
              </button>
            </SheetTrigger>
            <SheetContent
              side="right"
              className="bg-background w-full border-none sm:w-80"
            >
              <SheetHeader className="flex h-20 flex-row items-center justify-between px-6 pb-4">
                <Link href="/">
                  <Image
                    src="/logo.svg"
                    width={104}
                    height={32}
                    alt="ARX"
                    className="h-6 w-auto"
                  />
                </Link>
              </SheetHeader>
              <nav className="flex flex-col p-6">
                {navLinks.map((link) => (
                  <Link
                    key={link.label}
                    href={link.href}
                    target={link.target}
                    onClick={() => setMobileMenuOpen(false)}
                    className="text-content-100 hover:text-content-100 border-white-10 flex items-center justify-between border-b py-4 transition-colors"
                  >
                    <span className="text-base">{link.label}</span>
                    <ChevronRight className="text-content-70 size-6" />
                  </Link>
                ))}
              </nav>
            </SheetContent>
          </Sheet>
        </div>
      </div>
    </header>
  );
};
