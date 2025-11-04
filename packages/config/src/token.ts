export interface Token {
  address: `0x${string}`;
  symbol: string;
  name: string;
  decimals: number;
  logoURI: string;
  chainId: number;
}

export const isNativeToken = (address: `0x${string}`): boolean => {
  return address === "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
};

export const TESTNET_TOKENS: Token[] = [
  {
    address: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
    symbol: "ETH",
    name: "Ethereum",
    decimals: 18,
    logoURI: "/tokens/eth.svg",
    chainId: 11155111,
  },
  {
    address: process.env.NEXT_PUBLIC_USDC as
      | `0x${string}`
      | "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
    symbol: "USDC",
    name: "USD Coin",
    decimals: 6,
    logoURI: "/tokens/usdc.svg",
    chainId: 11155111,
  },
  {
    address: "0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0",
    symbol: "USDT",
    name: "Tether USD",
    decimals: 6,
    logoURI: "/tokens/usdt.svg",
    chainId: 11155111,
  },
  {
    address: "0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357",
    symbol: "DAI",
    name: "Dai Stablecoin",
    decimals: 18,
    logoURI: "/tokens/dai.svg",
    chainId: 11155111,
  },
  {
    address: "0xA4DDb0963792972C6D832aF6C88F9bd4fe30064D",
    symbol: "ARX",
    name: "ARX",
    decimals: 6,
    logoURI: "/tokens/arx.svg",
    chainId: 11155111,
  },
];

export const ETH_TOKENS: Token[] = [
  {
    address: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
    symbol: "ETH",
    name: "Ethereum",
    decimals: 18,
    logoURI: "/tokens/eth.svg",
    chainId: 1,
  },
  {
    address: "0xA4DDb0963792972C6D832aF6C88F9bd4fe30064D",
    symbol: "ARX",
    name: "ARX",
    decimals: 6,
    logoURI: "/tokens/arx.svg",
    chainId: 1,
  },
  {
    address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    symbol: "USDC",
    name: "USD Coin",
    decimals: 6,
    logoURI: "/tokens/usdc.svg",
    chainId: 1,
  },
  {
    address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
    symbol: "USDT",
    name: "Tether USD",
    decimals: 6,
    logoURI: "/tokens/usdt.svg",
    chainId: 1,
  },
  {
    address: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    symbol: "DAI",
    name: "Dai Stablecoin",
    decimals: 18,
    logoURI: "/tokens/dai.svg",
    chainId: 1,
  },
  {
    address: "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
    symbol: "WBTC",
    name: "Wrapped Bitcoin",
    decimals: 8,
    logoURI: "/tokens/btc.svg",
    chainId: 1,
  },
];

export const getTokensByChainId = (chainId: number): Token[] => {
  switch (chainId) {
    case 1:
      return ETH_TOKENS.filter((token) => token.chainId === 1);
    case 11155111:
    case 5:
      return TESTNET_TOKENS.filter((token) => token.chainId === chainId);
    default:
      return [];
  }
};

export const getTokenBySymbol = (
  symbol: string,
  chainId: number,
): Token | undefined => {
  const tokens = getTokensByChainId(chainId);
  return tokens.find(
    (token) => token.symbol.toLowerCase() === symbol.toLowerCase(),
  );
};

export const getTokensByChainIdSafe = (chainId: number): Token[] | null => {
  const tokens = getTokensByChainId(chainId);
  return tokens.length > 0 ? tokens : null;
};

export const getTokenByAddressSafe = (
  address: `0x${string}`,
  chainId: number,
): Token | null => {
  const token = getTokenByAddress(address, chainId);
  return token || null;
};

export const getTokenBySymbolSafe = (
  symbol: string,
  chainId: number,
): Token | null => {
  const token = getTokenBySymbol(symbol, chainId);
  return token || null;
};

export const getTokenByAddress = (
  address: `0x${string}`,
  chainId: number,
): Token | undefined => {
  const tokens = getTokensByChainId(chainId);
  return tokens.find(
    (token) => token.address.toLowerCase() === address.toLowerCase(),
  );
};
