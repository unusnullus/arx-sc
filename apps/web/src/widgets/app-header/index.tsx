"use client";

import { useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { Menu, X } from "lucide-react";

import { ConnectWallet } from "@/features/connect-wallet";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@arx/ui/components";

export const AppHeader = () => {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const navLinks = [
    { href: "/", label: "GitHub" },
    { href: "/", label: "GitBook" },
    { href: "/", label: "Etherscan" },
    { href: "/", label: "CoinMarketCap" },
  ];

  return (
    <header className="sticky top-0 z-40 flex w-full items-center justify-between gap-2 px-4 py-4 backdrop-blur-md md:px-6 md:py-5 lg:px-10 lg:py-5.5">
      <div className="flex w-full items-center justify-between gap-3">
        <div className="flex items-center justify-start md:w-52">
          <Image
            src="/logo.svg"
            width={104}
            height={32}
            alt="ARX"
            className="h-6 w-auto md:h-8"
          />
        </div>

        <nav className="hidden items-center gap-6 lg:flex">
          {navLinks.map((link) => (
            <Link
              key={link.label}
              href={link.href}
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
          <DropdownMenu open={mobileMenuOpen} onOpenChange={setMobileMenuOpen}>
            <DropdownMenuTrigger asChild>
              <button
                className="text-content-100 transition-colors lg:hidden"
                aria-label="Toggle menu"
              >
                {mobileMenuOpen ? (
                  <X className="h-6 w-6" />
                ) : (
                  <Menu className="h-6 w-6" />
                )}
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent
              align="end"
              className="bg-content-grey shadow-white-7 mt-2 mr-2 w-40 border-none shadow-md"
              sideOffset={8}
            >
              {navLinks.map((link) => (
                <DropdownMenuItem key={link.label} asChild>
                  <Link
                    href={link.href}
                    onClick={() => setMobileMenuOpen(false)}
                    className="text-content-70 cursor-pointer"
                  >
                    {link.label}
                  </Link>
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
    </header>
  );
};
