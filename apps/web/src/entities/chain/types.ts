export interface ChainConfig {
  id: number;
  name: string;
  icon: string;
  color: string;
  testnet: boolean;
  nativeCurrency: {
    name: string;
    symbol: string;
    decimals: number;
  };
  blockExplorer?: string;
  rpcUrl?: string;
}
