import { ETHERSCAN_BASE_URL } from "./constants";

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
  ARX_GOVERNOR?: `0x${string}`;
  ARX_TIMELOCK?: `0x${string}`;
  ARX_STACKING?: `0x${string}`;
  ARX_REGISTRY?: `0x${string}`;
  ARX_CLAIM?: `0x${string}`;
};

export { FALLBACK_CHAIN_ID, ETHERSCAN_BASE_URL } from "./constants";

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
    RATE_POOL: process.env.NEXT_PUBLIC_RATE_POOL as `0x${string}` | undefined,
    ARX_ZAPPER: process.env.NEXT_PUBLIC_ARX_ZAPPER as `0x${string}` | undefined,
    ARX_GOVERNOR: process.env.NEXT_PUBLIC_ARX_GOVERNOR as
      | `0x${string}`
      | undefined,
    ARX_TIMELOCK: process.env.NEXT_PUBLIC_ARX_TIMELOCK as
      | `0x${string}`
      | undefined,
  },
  // Sepolia
  11155111: {
    ARX: "0x98368da6b30477347d0cb93fe6cff9d1cdb61666" as `0x${string}`,
    ARX_TOKEN_SALE:
      "0x00bCef066Ccf04Bf52D17c55afA4D1c7bB4D8F11" as `0x${string}`,
    ARX_ZAP_ROUTER: process.env.NEXT_PUBLIC_ARX_ZAP_ROUTER as
      | `0x${string}`
      | undefined,
    USDC: process.env.NEXT_PUBLIC_USDC as `0x${string}` | undefined,
    WETH9: "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14" as `0x${string}`,
    UNISWAP_V3_SWAPROUTER: process.env.NEXT_PUBLIC_UNISWAP_V3_SWAPROUTER as
      | `0x${string}`
      | undefined,
    UNISWAP_V3_QUOTER: process.env.NEXT_PUBLIC_UNISWAP_V3_QUOTER as
      | `0x${string}`
      | undefined,
    SILO_TREASURY: process.env.NEXT_PUBLIC_SILO_TREASURY as
      | `0x${string}`
      | undefined,
    RATE_POOL: "0x355bA1b1fF856c901532670664502D9ada9823EF" as `0x${string}`,
    ARX_ZAPPER: "0xade460b1765f56500e32d01bfe8c061fc37b10bf" as `0x${string}`,
    ARX_GOVERNOR: "0x5D1B375C8DC2c27e4cc1F92d524e27efF19f2E17" as `0x${string}`,
    ARX_TIMELOCK: "0x1da6778Cc4901FfF5C9089415E97aC487442bfe4" as `0x${string}`,
    ARX_STACKING: "0xcC606DE48665E6BaDAA53aeF265898594Bc77d00" as `0x${string}`,
    ARX_REGISTRY: "0x37B4EEaEf6E7788f5dE3F077f9e7f74F7F71C9BF" as `0x${string}`,
    ARX_CLAIM: "0x7961D8972EB5f25C88cb85B44660E7d295e46054" as `0x${string}`,
  },
  1: {
    ARX: "0x53da93194bB7Ea02Afcb2c500f8316897a4f260a" as `0x${string}`,
    ARX_TOKEN_SALE:
      "0x40E21Dfa8625766C845329331256CB0113d2cd2c" as `0x${string}`,
    RATE_POOL: "0xAc5D5E90EB0812412dF4625097EB94fEB52480e1" as `0x${string}`,
    ARX_ZAPPER: "0x5347965580ccEBfCB0324d4598396aCeEd3CEeC8" as `0x${string}`,
    ARX_TIMELOCK: "0x41BC0488ae1B4cBE7caC59D41b9f4B7b5b282C63" as `0x${string}`,
    ARX_GOVERNOR: "0x707e534045E39045492F4B1f64A6e01CedD24b52" as `0x${string}`,
    ARX_STACKING: "0x748b52e54C3107A749b32Fc87F71ac9F18d2C4D3" as `0x${string}`,
    ARX_REGISTRY: "0x43015B15D3c4be2b70EF9Dd1Ba1D7f4b1091c8D0" as `0x${string}`,
    ARX_CLAIM: "0x4B5eC6d2F6fD65aAdE351B7b59a892EA32EDbEe9" as `0x${string}`,
    USDC: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" as `0x${string}`,
    WETH9: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2" as `0x${string}`,
  },
};

export const constants = {
  defaultSlippageBps: 100, // 1%
  defaultDeadlineMinutes: 20,
};

export const etherscanBaseUrl = (chainId: number) => {
  return ETHERSCAN_BASE_URL[chainId as keyof typeof ETHERSCAN_BASE_URL];
};

export * from "./token";
