"use client";

import Link from "next/link";

import { format } from "date-fns";
import { cn } from "@arx/ui/lib";
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@arx/ui/components";

export const RecentTransaction = () => {
  // if (!zapperAddress) {
  //   return (
  //     <Card>
  //       <CardHeader>
  //         <CardTitle className="flex items-center justify-between">
  //           <span className="text-base font-semibold sm:text-lg lg:text-xl">Recent Transactions</span>
  //         </CardTitle>
  //       </CardHeader>
  //       <CardContent>
  //         <div className="text-base-secondary py-4 text-center">Network not supported</div>
  //       </CardContent>
  //     </Card>
  //   );
  // }

  // if (isLoading) {
  //   return (
  //     <Card>
  //       <CardHeader>
  //         <CardTitle className="flex items-center justify-between">
  //           <span className="text-base font-semibold sm:text-lg lg:text-xl">Recent Transactions</span>
  //         </CardTitle>
  //       </CardHeader>
  //       <CardContent>
  //         <div className="flex flex-col">
  //           {Array.from({ length: 5 }).map((_, index) => (
  //             <TransactionSkeleton key={index} />
  //           ))}
  //         </div>
  //       </CardContent>
  //     </Card>
  //   );
  // }

  // if (error) {
  //   return (
  //     <Card>
  //       <CardHeader>
  //         <CardTitle className="flex items-center justify-between">
  //           <span className="text-base font-semibold sm:text-lg lg:text-xl">Recent Transactions</span>
  //         </CardTitle>
  //       </CardHeader>
  //       <CardContent>
  //         <div className="text-base-secondary py-4 text-center">Failed to load transactions</div>
  //       </CardContent>
  //     </Card>
  //   );
  // }

  // if (transactionsData?.transactions.length === 0) {
  //   return (
  //     <Card>
  //       <CardHeader>
  //         <CardTitle className="flex items-center justify-between">
  //           <span className="text-base font-semibold sm:text-lg lg:text-xl">Recent Transactions</span>
  //         </CardTitle>
  //       </CardHeader>
  //       <CardContent>
  //         <div className="text-base-secondary py-4 text-center">No transactions found</div>
  //       </CardContent>
  //     </Card>
  //   );
  // }

  // const filteredTransactions = transactionsData?.transactions
  //   ? filterTransactionsByType(transactionsData.transactions, TRANSACTION_TYPE_ALLOWED_TYPES)
  //       .slice(0, 5)
  //       .map(formatTransactionForDisplay)
  //       .filter((tx) => !!tx)
  //   : [];

  const filteredTransactions = [
    {
      hash: "0x1234567890123456789012345678901234567890",
      displayName: "RedeemRequest",
      age: "2025-11-04",
      tokenTransfers: [],
      value: "100",
    },
    {
      hash: "0x1234567890123456789012345678901234567890",
      displayName: "RedeemRequest",
      age: "2025-11-04",
      status: "failed",
      tokenTransfers: [],
      value: "200",
    },
    {
      hash: "0x1234567890123456789012345678901234567890",
      displayName: "ClaimRedeem",
      age: "2025-11-03",
      status: "success",
      tokenTransfers: [],
      value: "300",
    },
    {
      hash: "0x1234567890123456789012345678901234567890",
      displayName: "RedeemRequest",
      age: "2025-11-03",
      tokenTransfers: [],
      value: "300",
    },
    {
      hash: "0x1234567890123456789012345678901234567890",
      displayName: "ClaimRedeem",
      age: "2025-11-03",
      status: "success",
      tokenTransfers: [],
      value: "400",
    },
  ];

  return (
    <Card className="gap-3 lg:gap-4">
      <CardHeader>
        <CardTitle className="flex items-center justify-between">
          <span className="text-base font-semibold sm:text-lg lg:text-xl">
            Recent Transactions
          </span>
          <Link href="/transactions-history">
            <Button
              variant="link"
              className="text-secondary hover:text-secondary/70 text-sm"
              size="sm"
            >
              View All
            </Button>
          </Link>
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex flex-col">
          {filteredTransactions.map((tx) => (
            <div
              key={tx.hash}
              className="border-white-10 flex items-center justify-between border-b py-2 last:border-b-0"
            >
              <div className="flex items-center gap-2">
                {/* <Tooltip useTouch>
                  <TooltipTrigger asChild>
                    <Button
                      variant="ghost"
                      size="icon"
                      onClick={() => window.open(`${getExplorerUrl(targetChainId)}/tx/${tx.hash}`, "_blank")}
                    >
                      <ExternalLink className="text-base-secondary size-4" />
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent>View Transaction</TooltipContent>
                </Tooltip> */}
                <div className="flex flex-col gap-1">
                  <span
                    className={cn("text-content-70 text-sm sm:text-base", {
                      "text-success": tx.status === "success",
                      "text-error": tx.status === "failed",
                    })}
                  >
                    {tx.displayName}
                  </span>

                  <span className="text-content-50 text-xs">
                    {format(new Date(tx.age), "dd MMM yyyy")}
                  </span>
                </div>
              </div>
              <span className="text-content-50 text-sm sm:text-base">
                {tx.value}
              </span>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
};
