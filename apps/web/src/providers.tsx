"use client";
import { WagmiProvider, createConfig, http } from "wagmi";
import { mainnet, sepolia, baseSepolia, foundry } from "wagmi/chains";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RainbowKitProvider, getDefaultConfig } from "@rainbow-me/rainbowkit";
import { PropsWithChildren } from "react";

const queryClient = new QueryClient();

const chains = [mainnet, sepolia, baseSepolia, foundry] as const;

const wagmiConfig = createConfig(
  getDefaultConfig({
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
  }),
);

export default function Providers({ children }: PropsWithChildren) {
  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>{children}</RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
