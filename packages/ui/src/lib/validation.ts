import { parseUnits } from "viem";

import { Token } from "@/shared/config";

export interface ValidationResult {
  isValid: boolean;
  error?: string;
}

export const validateAmount = (
  amount: string,
  token: Token,
  balance: bigint,
): ValidationResult => {
  if (!amount || amount.trim() === "") {
    return { isValid: false, error: "Amount is required" };
  }

  if (amount === "0") {
    return { isValid: false, error: "Amount must be greater than 0" };
  }

  try {
    const amountWei = parseUnits(amount, token.decimals);

    if (amountWei > balance) {
      return { isValid: false, error: "Insufficient balance" };
    }

    const minAmount = parseUnits("0.0001", token.decimals);
    if (amountWei < minAmount) {
      return { isValid: false, error: "Amount too small (minimum 0.0001)" };
    }

    return { isValid: true };
  } catch (_) {
    return { isValid: false, error: "Invalid amount format" };
  }
};

export const validateWalletConnection = (
  address: `0x${string}` | undefined,
  chainId: number | undefined,
): ValidationResult => {
  if (!address) {
    return { isValid: false, error: "Please connect your wallet" };
  }

  if (!chainId) {
    return { isValid: false, error: "Please select a network" };
  }

  return { isValid: true };
};

export const validateToken = (token: Token | undefined): ValidationResult => {
  if (!token) {
    return { isValid: false, error: "Please select a token" };
  }

  return { isValid: true };
};
