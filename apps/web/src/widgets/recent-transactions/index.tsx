"use client";

import { format } from "date-fns";
import { cn } from "@arx/ui/lib";
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Skeleton,
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@arx/ui/components";
import { useGetRecentTransactions } from "@/entities/transactions";
import { ExternalLink } from "lucide-react";

export const RecentTransaction = () => {
  const { transactions, isLoading, error } = useGetRecentTransactions();

  if (isLoading) {
    return (
      <Card className="gap-3 lg:gap-4">
        <CardHeader>
          <CardTitle className="flex items-center justify-between">
            <span className="text-base font-semibold sm:text-lg lg:text-xl">
              Recent Transactions
            </span>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex flex-col">
            {Array.from({ length: 5 }).map((_, index) => (
              <div
                key={index}
                className="border-white-10 flex items-center justify-between border-b py-2 last:border-b-0"
              >
                <div className="flex items-center gap-2">
                  <Skeleton className="size-9 rounded-md" />
                  <div className="flex flex-col gap-2">
                    <Skeleton className="h-5 w-24" />
                    <Skeleton className="h-4 w-16" />
                  </div>
                </div>
                <Skeleton className="h-5 w-16" />
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    );
  }

  if (error) {
    return (
      <Card className="gap-3 lg:gap-4">
        <CardHeader>
          <CardTitle className="flex items-center justify-between">
            <span className="text-base font-semibold sm:text-lg lg:text-xl">
              Recent Transactions
            </span>
          </CardTitle>
        </CardHeader>
        <CardContent className="h-full">
          <div className="text-content-50 flex h-full items-center justify-center py-4 text-center">
            Failed to load transactions
          </div>
        </CardContent>
      </Card>
    );
  }

  if (transactions.length === 0) {
    return (
      <Card className="gap-3 lg:gap-4">
        <CardHeader>
          <CardTitle className="flex items-center justify-between">
            <span className="text-base font-semibold sm:text-lg lg:text-xl">
              Recent Transactions
            </span>
          </CardTitle>
        </CardHeader>
        <CardContent className="h-full">
          <div className="text-content-50 flex h-full items-center justify-center py-4 text-center">
            No transactions found
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="gap-3 lg:gap-4">
      <CardHeader>
        <CardTitle className="flex items-center justify-between">
          <span className="text-base font-semibold sm:text-lg lg:text-xl">
            Recent Transactions
          </span>
          {/* <Link href="/transactions-history">
            <Button
              variant="link"
              className="text-secondary hover:text-secondary/70 text-sm"
              size="sm"
            >
              View All
            </Button>
          </Link> */}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex flex-col">
          {transactions.map(({ tx, arx, datetime, status }) => (
            <div
              key={tx}
              className="border-white-10 flex items-center justify-between border-b py-2 last:border-b-0"
            >
              <div className="flex items-center gap-2">
                <Tooltip useTouch>
                  <TooltipTrigger asChild>
                    <Button
                      variant="ghost"
                      size="icon"
                      onClick={() =>
                        window.open(
                          `https://sepolia.etherscan.io/tx/${tx}`,
                          "_blank",
                        )
                      }
                    >
                      <ExternalLink className="text-base-secondary size-4" />
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent>View Transaction</TooltipContent>
                </Tooltip>
                <div className="flex flex-col gap-1">
                  <span
                    className={cn("text-content-70 text-sm sm:text-base", {
                      "text-success": status === "success",
                      "text-error": status === "failed",
                    })}
                  >
                    Purchased
                  </span>

                  <span className="text-content-50 text-xs">
                    {format(new Date(datetime), "dd MMM yyyy")}
                  </span>
                </div>
              </div>
              <span className="text-content-50 text-sm sm:text-base">
                {arx} ARX
              </span>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
};
