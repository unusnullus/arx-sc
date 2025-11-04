"use client";
import Image from "next/image";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useBalance, useChainId, usePublicClient } from "wagmi";
import { useEffect, useMemo, useState } from "react";
import { addressesByChain } from "@arx/config";

export default function Header() {
  const chainId = useChainId();
  const { address, isConnected } = useAccount();
  const publicClient = usePublicClient({ chainId });
  const cfg = useMemo(() => addressesByChain[chainId] || {}, [chainId]);
  const { data: ethBal } = useBalance({
    address,
    chainId,
    query: { enabled: !!address },
  });
  const { data: usdcBal } = useBalance({
    address,
    token: cfg.USDC as `0x${string}` | undefined,
    chainId,
    query: { enabled: !!address && !!cfg.USDC },
  });

  const [gasPriceGwei, setGasPriceGwei] = useState<string>("-");
  const [networkName, setNetworkName] = useState<string>("-");

  useEffect(() => {
    let active = true;
    async function load() {
      try {
        const [gp, net] = await Promise.all([
          publicClient?.getGasPrice(),
          publicClient?.getChainId(),
        ]);
        if (!active) return;
        if (gp != null) setGasPriceGwei((Number(gp) / 1e9).toFixed(2));
        if (net != null)
          setNetworkName(net === 11155111 ? "Sepolia" : String(net));
      } catch {}
    }
    load();
    const id = setInterval(load, 15000);
    return () => {
      active = false;
      clearInterval(id);
    };
  }, [publicClient]);

  return (
    <header className="header-surface sticky top-0 z-40 flex items-center justify-center">
      <div className="container px-4 py-3 flex items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <Image src="/logo-dark.svg" width={28} height={28} alt="ARX" />
          <span className="text-sm font-medium tracking-wide">ARX NET</span>
        </div>
        <div className="flex items-center gap-4 text-xs text-neutral-300">
          <div className="hidden sm:flex items-center gap-1">
            <span className="text-neutral-500">Network</span>
            <span className="px-2 py-0.5 rounded-full border border-white/10">
              {networkName}
            </span>
          </div>
          <div className="hidden sm:flex items-center gap-1">
            <span className="text-neutral-500">Gas</span>
            <span>{gasPriceGwei} gwei</span>
          </div>
          {isConnected && (
            <>
              <div className="hidden md:flex items-center gap-1">
                <span className="text-neutral-500">ETH</span>
                <span>
                  {ethBal ? (Number(ethBal.value) / 1e18).toFixed(4) : "-"}
                </span>
              </div>
              <div className="hidden md:flex items-center gap-1">
                <span className="text-neutral-500">USDC</span>
                <span>
                  {usdcBal ? (Number(usdcBal.value) / 1e6).toFixed(2) : "-"}
                </span>
              </div>
            </>
          )}
          <ConnectButton />
        </div>
      </div>
    </header>
  );
}
