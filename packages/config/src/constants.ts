export const FALLBACK_CHAIN_ID =
  Number(process.env.NEXT_PUBLIC_CHAIN_ID) ?? 11155111;
export const ETHERSCAN_BASE_URL = {
  1: "https://etherscan.io",
  11155111: "https://sepolia.etherscan.io",
};
