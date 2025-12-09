export type ChainAddresses = {
  ARX?: `0x${string}`;
  ARX_TOKEN_SALE?: `0x${string}`;
  ARX_ZAP_ROUTER?: `0x${string}`;
  USDC?: `0x${string}`;
  WETH9?: `0x${string}`;
  UNISWAP_V3_SWAPROUTER?: `0x${string}`;
  UNISWAP_V3_QUOTER?: `0x${string}`;
  SILO_TREASURY?: `0x${string}`;
  RATE_POOL?: `0x${string}`;
  ARX_ZAPPER?: `0x${string}`;
};

export const addressesByChain: Record<number, ChainAddresses> = {
  // Local Anvil / Foundry
  31337: {
    ARX: process.env.NEXT_PUBLIC_ARX as `0x${string}` | undefined,
    ARX_TOKEN_SALE: process.env.NEXT_PUBLIC_ARX_TOKEN_SALE as
      | `0x${string}`
      | undefined,
    ARX_ZAP_ROUTER: process.env.NEXT_PUBLIC_ARX_ZAP_ROUTER as
      | `0x${string}`
      | undefined,
    USDC: process.env.NEXT_PUBLIC_USDC as `0x${string}` | undefined,
    WETH9: process.env.NEXT_PUBLIC_WETH9 as `0x${string}` | undefined,
    UNISWAP_V3_SWAPROUTER: process.env.NEXT_PUBLIC_UNISWAP_V3_SWAPROUTER as
      | `0x${string}`
      | undefined,
    UNISWAP_V3_QUOTER: process.env.NEXT_PUBLIC_UNISWAP_V3_QUOTER as
      | `0x${string}`
      | undefined,
    SILO_TREASURY: process.env.NEXT_PUBLIC_SILO_TREASURY as
      | `0x${string}`
      | undefined,
  },
  // Sepolia
  11155111: {
    ARX: process.env.NEXT_PUBLIC_ARX as `0x${string}` | undefined,
    ARX_TOKEN_SALE: process.env.NEXT_PUBLIC_ARX_TOKEN_SALE as
      | `0x${string}`
      | undefined,
    ARX_ZAP_ROUTER: process.env.NEXT_PUBLIC_ARX_ZAP_ROUTER as
      | `0x${string}`
      | undefined,
    USDC: process.env.NEXT_PUBLIC_USDC as `0x${string}` | undefined,
    WETH9: process.env.NEXT_PUBLIC_WETH9 as `0x${string}` | undefined,
    UNISWAP_V3_SWAPROUTER: process.env.NEXT_PUBLIC_UNISWAP_V3_SWAPROUTER as
      | `0x${string}`
      | undefined,
    UNISWAP_V3_QUOTER: process.env.NEXT_PUBLIC_UNISWAP_V3_QUOTER as
      | `0x${string}`
      | undefined,
    SILO_TREASURY: process.env.NEXT_PUBLIC_SILO_TREASURY as
      | `0x${string}`
      | undefined,
    RATE_POOL: process.env.NEXT_PUBLIC_RATE_POOL as `0x${string}` | undefined,
    ARX_ZAPPER: process.env.NEXT_PUBLIC_ARX_ZAPPER as `0x${string}` | undefined,
  },
  // Base Sepolia (example placeholders)
  84532: {
    ARX: undefined,
    ARX_TOKEN_SALE: undefined,
    ARX_ZAP_ROUTER: undefined,
    USDC: process.env.NEXT_PUBLIC_USDC as `0x${string}` | undefined,
    WETH9: process.env.NEXT_PUBLIC_WETH9 as `0x${string}` | undefined,
    UNISWAP_V3_SWAPROUTER: process.env.NEXT_PUBLIC_UNISWAP_V3_SWAPROUTER as
      | `0x${string}`
      | undefined,
    UNISWAP_V3_QUOTER: process.env.NEXT_PUBLIC_UNISWAP_V3_QUOTER as
      | `0x${string}`
      | undefined,
    SILO_TREASURY: process.env.NEXT_PUBLIC_SILO_TREASURY as
      | `0x${string}`
      | undefined,
  },
};

export const constants = {
  defaultSlippageBps: 100, // 1%
  defaultDeadlineMinutes: 20,
};

export const FALLBACK_CHAIN_ID =
  Number(process.env.NEXT_PUBLIC_CHAIN_ID) ?? 31337;

export * from "./token";
