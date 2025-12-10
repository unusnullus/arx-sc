"use client";

import { ReactElement } from "react";

import { useAccount } from "wagmi";

import { CoinAmountInput } from "@/features/coin-amount-input";
import { LiquidityForm } from "@/features/liquidity-form";
import { TokenMaxBalance } from "@/features/max-balance";
import { SelectCoin } from "@/features/select-coin";
import { Token, getTokensByChainIdSafe, FALLBACK_CHAIN_ID } from "@arx/config";
import { Card, CardContent, CardHeader, CardTitle } from "@arx/ui/components";

export const LiquidityWidget = () => {
  const { chainId } = useAccount();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;
  const tokens = getTokensByChainIdSafe(targetChainId);

  const renderSelectCoin = (onSelect: (token: Token) => void): ReactElement => (
    <SelectCoin onSelect={onSelect} tokens={tokens || undefined} />
  );

  const renderCoinAmountInput = (
    token: Token,
    value: string,
    onChange: (value: string) => void,
    userBalance?: bigint,
  ): ReactElement => (
    <CoinAmountInput
      token={token}
      value={value}
      onChange={onChange}
      balance={userBalance}
    />
  );

  const renderMaxBalance = (
    token: Token,
    onMaxBalance: (value: string) => void,
  ): ReactElement => (
    <TokenMaxBalance token={token} onMaxBalance={onMaxBalance} />
  );

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-content-100 text-lg font-semibold">
          Liquidity
        </CardTitle>
        <p className="text-content-70 text-sm">
          Add liquidity to the pool to earn fees
        </p>
      </CardHeader>
      <CardContent>
        <LiquidityForm
          renderSelectCoin={renderSelectCoin}
          renderCoinAmountInput={renderCoinAmountInput}
          renderMaxBalance={renderMaxBalance}
        />
      </CardContent>
    </Card>
  );
};
