import { PoolTransactions } from "@/widgets/pool-transactions";
import { TokenInfo } from "@/widgets/token-info";
import { RecentTransaction } from "@/widgets/recent-transactions";

export default function BuyPage() {
  return (
    <main className="grid grid-cols-1 gap-4 px-4 md:grid-cols-2 md:px-0">
      <PoolTransactions className="md:max-w-full" />
      <TokenInfo />
      <RecentTransaction />
    </main>
  );
}
