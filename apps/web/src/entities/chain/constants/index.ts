import { ChainConfig } from "../types";

export enum Chains {
  MAINNET = 1,
  SEPOLIA = 11155111,
}

export const CHAIN_CONFIG: Record<Chains, ChainConfig> = {
  [Chains.MAINNET]: {
    id: Chains.MAINNET,
    name: "Ethereum",
    icon: "/tokens/eth.svg",
    color: "#627EEA",
    testnet: false,
    nativeCurrency: {
      name: "Ether",
      symbol: "ETH",
      decimals: 18,
    },
    blockExplorer: "https://etherscan.io",
  },
  [Chains.SEPOLIA]: {
    id: Chains.SEPOLIA,
    name: "Sepolia",
    icon: "/tokens/eth.svg",
    color: "#627EEA",
    testnet: true,
    nativeCurrency: {
      name: "Sepolia Ether",
      symbol: "ETH",
      decimals: 18,
    },
    blockExplorer: "https://sepolia.etherscan.io",
  },
} as const;

export const SUPPORTED_CHAINS = Object.values(CHAIN_CONFIG);
export const MAINNET_CHAINS = SUPPORTED_CHAINS.filter(
  (chain) => !chain.testnet,
);
export const TESTNET_CHAINS = SUPPORTED_CHAINS.filter((chain) => chain.testnet);
