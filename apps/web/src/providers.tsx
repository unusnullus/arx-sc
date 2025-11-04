"use client";
import "@rainbow-me/rainbowkit/styles.css";
import { WagmiProvider, http, createConfig } from "wagmi";
import {
  mainnet,
  sepolia as baseSepoliaChain,
  baseSepolia,
  foundry,
} from "wagmi/chains";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import {
  RainbowKitProvider,
  getDefaultConfig,
  darkTheme,
} from "@rainbow-me/rainbowkit";
import { PropsWithChildren, useEffect, useMemo, useState } from "react";

const queryClient = new QueryClient();

// Force Sepolia RPC to Infura
const SEPOLIA = {
  ...baseSepoliaChain,
  rpcUrls: {
    ...baseSepoliaChain.rpcUrls,
    default: {
      http: [
        process.env.NEXT_PUBLIC_RPC_SEPOLIA ||
          baseSepoliaChain.rpcUrls.default.http[0],
      ],
    },
    public: {
      http: [
        process.env.NEXT_PUBLIC_RPC_SEPOLIA ||
          baseSepoliaChain.rpcUrls.default.http[0],
      ],
    },
  },
} as const;

const chains = [mainnet, SEPOLIA, baseSepolia, foundry] as const;

export default function Providers({ children }: PropsWithChildren) {
  const isBrowser = typeof window !== "undefined";
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  const fallbackConfig = useMemo(() => {
    return createConfig({
      chains,
      transports: {
        [mainnet.id]: http(process.env.NEXT_PUBLIC_RPC_MAINNET),
        [SEPOLIA.id]: http(process.env.NEXT_PUBLIC_RPC_SEPOLIA),
        [baseSepolia.id]: http(process.env.NEXT_PUBLIC_RPC_BASE_SEPOLIA),
        [foundry.id]: http(
          process.env.NEXT_PUBLIC_RPC_LOCAL || "http://127.0.0.1:8545",
        ),
      },
      connectors: [],
      ssr: true,
    });
  }, []);
  const wagmiConfig = useMemo(() => {
    if (!isBrowser) return null;
    return getDefaultConfig({
      appName: "ARX",
      projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_ID || "demo",
      chains,
      transports: {
        [mainnet.id]: http(process.env.NEXT_PUBLIC_RPC_MAINNET),
        [SEPOLIA.id]: http(process.env.NEXT_PUBLIC_RPC_SEPOLIA),
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
    return (
      <WagmiProvider config={fallbackConfig}>
        <QueryClientProvider client={queryClient}>
          {children}
        </QueryClientProvider>
      </WagmiProvider>
    );
  }

  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        {mounted ? (
          <RainbowKitProvider theme={darkTheme()}>
            {children}
          </RainbowKitProvider>
        ) : (
          children
        )}
      </QueryClientProvider>
    </WagmiProvider>
  );
}
