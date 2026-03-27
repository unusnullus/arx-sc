"use client";

import { useEffect, useRef } from "react";
import { useAccount } from "wagmi";
import { toast } from "@arx/ui/components";

import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@arx/ui/components";
import { useVotingPower, useDelegation } from "@/entities/governance";
import { DelegateForm } from "@/features/delegate-votes";

export const VotingPowerCard = () => {
  const { address, isConnected } = useAccount();
  const { formattedVotes, formattedGovernorVotes, isLoading, error } =
    useVotingPower();
  const {
    isDelegated,
    delegatee,
    isLoading: isLoadingDelegation,
  } = useDelegation();
  const hasShownNotification = useRef(false);

  useEffect(() => {
    if (
      isConnected &&
      address &&
      delegatee &&
      !isDelegated &&
      !isLoadingDelegation &&
      !hasShownNotification.current
    ) {
      toast.info("Your votes are not delegated. Delegate now to participate.");
      hasShownNotification.current = true;
    }
  }, [isConnected, address, delegatee, isDelegated, isLoadingDelegation]);

  if (!isConnected) {
    return (
      <Card className="bg-white-7 gap-3 rounded-[20px] md:rounded-4xl lg:gap-4">
        <CardHeader>
          <CardTitle className="text-content-100 text-base font-semibold sm:text-lg lg:text-xl">
            Your Voting Power
          </CardTitle>
          <CardDescription className="text-content-70 text-base">
            Connect your wallet to view your voting power
          </CardDescription>
        </CardHeader>
      </Card>
    );
  }

  return (
    <Card className="bg-white-7 h-fit gap-3 rounded-[20px] md:rounded-4xl lg:gap-4">
      <CardHeader>
        <CardTitle className="text-content-100 text-base font-semibold sm:text-lg lg:text-xl">
          Your Voting Power
        </CardTitle>
        <CardDescription className="text-content-70 text-base">
          Your current voting power and delegation status
        </CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-6">
        {isLoading ? (
          <div className="text-content-50 text-sm">Loading...</div>
        ) : error ? (
          <div className="text-error text-sm">Error loading voting power</div>
        ) : (
          <>
            <div className="flex flex-col gap-4">
              <div className="flex items-center justify-between">
                <span className="text-content-70 text-sm md:text-base">
                  Current Voting Power:
                </span>
                <span className="text-content-100 text-sm font-semibold md:text-base">
                  {formattedGovernorVotes} ARX
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-content-70 text-sm md:text-base">
                  Token Balance:
                </span>
                <span className="text-content-100 text-sm font-semibold md:text-base">
                  {formattedVotes} ARX
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-content-70 text-sm md:text-base">
                  Delegation Status:
                </span>
                <span
                  className={`text-sm font-semibold md:text-base ${
                    isDelegated ? "text-success" : "text-content-50"
                  }`}
                >
                  {isDelegated ? "Delegated" : "Not Delegated"}
                </span>
              </div>
              {delegatee && (
                <div className="flex items-center justify-between">
                  <span className="text-content-70 text-sm md:text-base">
                    Delegatee:
                  </span>
                  <span className="text-content-100 font-mono">
                    {delegatee.slice(0, 6)}...{delegatee.slice(-4)}
                  </span>
                </div>
              )}
            </div>

            {!isDelegated && <DelegateForm />}
          </>
        )}
      </CardContent>
    </Card>
  );
};
