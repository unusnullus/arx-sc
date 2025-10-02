"use client";
import { WagmiProvider, http } from "wagmi";
import { mainnet, sepolia, baseSepolia, foundry } from "wagmi/chains";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RainbowKitProvider, getDefaultConfig } from "@rainbow-me/rainbowkit";
import { PropsWithChildren, useMemo } from "react";

const queryClient = new QueryClient();

const chains = [mainnet, sepolia, baseSepolia, foundry] as const;

export default function Providers({ children }: PropsWithChildren) {
  const isBrowser = typeof window !== "undefined";
  const wagmiConfig = useMemo(() => {
    if (!isBrowser) return null;
    return getDefaultConfig({
      appName: "ARX",
      projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_ID || "demo",
      chains,
      transports: {
        [mainnet.id]: http(process.env.NEXT_PUBLIC_RPC_MAINNET),
        [sepolia.id]: http(process.env.NEXT_PUBLIC_RPC_SEPOLIA),
        [baseSepolia.id]: http(process.env.NEXT_PUBLIC_RPC_BASE_SEPOLIA),
        [foundry.id]: http(
          process.env.NEXT_PUBLIC_RPC_LOCAL || "http://127.0.0.1:8545",
        ),
      },
      ssr: true,
    });
  }, [isBrowser]);

  if (!isBrowser || !wagmiConfig) {
    // Avoid initializing WalletConnect on the server to prevent indexedDB errors
    return <>{children}</>;
  }

  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>{children}</RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
