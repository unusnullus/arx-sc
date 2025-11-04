"use client";

import { useAccount } from "wagmi";

import { usePermitSettings } from "@/entities/permit";
import { CoinAmountInput } from "@/features/coin-amount-input";
import { BuyForm } from "@/features/buy-form";
import { TokenMaxBalance } from "@/features/max-balance";
import { PermitSelection } from "@/features/permit-selection";
import { SelectCoin } from "@/features/select-coin";
import { FALLBACK_CHAIN_ID, Token, getTokensByChainId } from "@arx/config";
import { Card, CardContent, CardHeader } from "@arx/ui/components";

export const PoolTransactions = () => {
  const { chainId } = useAccount();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;

  const tokens = getTokensByChainId(targetChainId).filter(
    (token) => token.symbol !== "ARX",
  );

  const { settings, updateSettings } = usePermitSettings();

  return (
    <Card className="bg-white-7 w-full max-w-[586px] gap-0">
      <CardHeader>
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold">
              Buy <span className="text-primary">ARX</span>
            </h2>
          </div>
          <PermitSelection
            settings={settings}
            updateSettings={updateSettings}
          />
        </div>
      </CardHeader>
      <CardContent>
        <BuyForm
          renderSelectCoin={(onSelect: (token: Token) => void) => (
            <SelectCoin onSelect={onSelect} tokens={tokens} />
          )}
          renderCoinAmountInput={(
            token: Token,
            value: string,
            onChange: (value: string) => void,
          ) => (
            <CoinAmountInput token={token} value={value} onChange={onChange} />
          )}
          renderMaxBalance={(
            token: Token,
            onMaxBalance: (value: string) => void,
          ) => <TokenMaxBalance token={token} onMaxBalance={onMaxBalance} />}
          permitSettings={settings}
        />
      </CardContent>
    </Card>
  );
};
