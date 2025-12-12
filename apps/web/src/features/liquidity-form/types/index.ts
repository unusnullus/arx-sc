import { Token } from "@arx/config";
import { ReactElement } from "react";

export interface LiquidityFormProps {
  renderSelectCoin: (onSelect: (token: Token) => void) => ReactElement;
  renderCoinAmountInput: (
    token: Token,
    value: string,
    onChange: (value: string) => void,
    userBalance?: bigint,
  ) => ReactElement;
  renderMaxBalance: (
    token: Token,
    onMaxBalance: (value: string) => void,
  ) => ReactElement;
}

export interface LiquidityStep {
  id: string;
  title: string;
  description?: string;
  status: "pending" | "active" | "completed" | "processing";
}

export interface LiquidityPoolInfo {
  usdcBalance: string;
  usadBalance: string;
  userLpBalance: string;
  userLpShare: string;
  estimatedUsdc: string;
  estimatedUsad: string;
}

export type LiquidityAction = "add" | "remove" | "swap";
