"use client";

import { useState, useEffect, useRef, useMemo } from "react";
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
import {
  addressesByChain,
  etherscanBaseUrl,
  FALLBACK_CHAIN_ID,
} from "@arx/config";
import { useAccount } from "wagmi";

export const AppHeader = () => {
  const { chainId } = useAccount();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [rotation, setRotation] = useState(0);
  const lastScrollY = useRef(0);

  const cfg = useMemo(
    () => addressesByChain[targetChainId] || {},
    [targetChainId],
  );

  const etherscanUrl = useMemo(
    () => etherscanBaseUrl(targetChainId),
    [targetChainId],
  );

  useEffect(() => {
    let rafId: number | null = null;

    const handleScroll = () => {
      if (rafId) return;

      rafId = requestAnimationFrame(() => {
        const currentScrollY = window.scrollY;
        const scrollDelta = currentScrollY - lastScrollY.current;

        setRotation((prev) => prev + scrollDelta * 0.5);
        lastScrollY.current = currentScrollY;
        rafId = null;
      });
    };

    window.addEventListener("scroll", handleScroll, { passive: true });

    return () => {
      window.removeEventListener("scroll", handleScroll);
      if (rafId) cancelAnimationFrame(rafId);
    };
  }, []);

  const navLinks = [
    { href: "https://www.arx.pro/", label: "Arx.Pro", target: "_blank" },
    {
      href: `${etherscanUrl}/address/${cfg.ARX}`,
      label: "Etherscan",
      target: "_blank",
    },
    {
      href: "https://github.com/unusnullus/arx-sc",
      label: "GitHub",
      target: "_blank",
    },
    { href: "https://docs.arx.pro/", label: "Documentation", target: "_blank" },
  ];

  return (
    <header className="sticky top-0 z-40 flex w-full items-center justify-between gap-2 px-4 py-4 backdrop-blur-md md:px-6 md:py-5 lg:px-10 lg:py-5.5">
      <div className="flex w-full items-center justify-between gap-3">
        <div className="flex items-center justify-start gap-3 md:w-52">
          <Link href="/" className="cursor-pointer">
            <div className="flex items-center gap-1 md:gap-2">
              <Image
                src="/logo-arx.svg"
                width={104}
                height={32}
                alt="ARX"
                priority
                fetchPriority="high"
                className="size-5 w-auto transition-transform duration-0 md:size-8"
                style={{ transform: `rotate(${rotation}deg)` }}
              />
              <span className="text-content-100 text-xl font-semibold md:text-3xl">
                ARX
              </span>
            </div>
          </Link>
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
              side="left"
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
                    priority
                    fetchPriority="high"
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
        </div>
      </div>
    </header>
  );
};
