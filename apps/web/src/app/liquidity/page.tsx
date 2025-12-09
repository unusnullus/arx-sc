import { LiquidityWidget } from "@/widgets/liquidity-widget";
import { PoolBalanceWidget } from "@/widgets/pool-balance-widget";

export default function LiquidityPage() {
  return (
    <div className="grid w-full grid-cols-1 gap-4 px-4 md:grid-cols-2 md:px-0">
      <LiquidityWidget />
      <PoolBalanceWidget className="h-fit" />
    </div>
  );
}
