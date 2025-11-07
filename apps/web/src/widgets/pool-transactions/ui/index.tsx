"use client";

import { useAccount } from "wagmi";

import { usePermitSettings } from "@/entities/permit";
import { CoinAmountInput } from "@/features/coin-amount-input";
import { BuyForm } from "@/features/buy-form";
import { TokenMaxBalance } from "@/features/max-balance";
import { SelectCoin } from "@/features/select-coin";
import { FALLBACK_CHAIN_ID, Token, getTokensByChainId } from "@arx/config";
import { Card, CardContent } from "@arx/ui/components";
import { cn } from "@arx/ui/lib";

export const PoolTransactions = ({ className }: { className?: string }) => {
  const { chainId } = useAccount();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;

  const tokens = getTokensByChainId(targetChainId).filter(
    (token) => token.symbol !== "ARX",
  );

  const { settings } = usePermitSettings();

  return (
    <Card
      className={cn(
        "bg-white-7 w-full gap-0 py-2 md:max-w-[586px] md:py-6",
        className,
      )}
    >
      {/* <CardHeader className="px-2 md:px-6">
        <div className="flex items-center justify-end">
          <PermitSelection
            settings={settings}
            updateSettings={updateSettings}
          />
        </div>
      </CardHeader> */}
      <CardContent className="px-2 md:px-6">
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
