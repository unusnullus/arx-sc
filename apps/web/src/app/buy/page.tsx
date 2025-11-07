import { PoolTransactions } from "@/widgets/pool-transactions";
import { TokenInfo } from "@/widgets/token-info";
import { RecentTransaction } from "@/widgets/recent-transactions";

export default function BuyPage() {
  return (
    <main className="grid grid-cols-1 gap-4 md:grid-cols-2">
      <PoolTransactions className="max-w-full" />
      <TokenInfo />
      <RecentTransaction />
    </main>
  );
}
