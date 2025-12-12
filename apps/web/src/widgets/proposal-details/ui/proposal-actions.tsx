"use client";

import { useEffect, useState } from "react";
import { Button, Spinner } from "@arx/ui/components";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@arx/ui/components";
import {
  Proposal,
  ProposalState,
  canQueue,
  canExecute,
  canCancel,
} from "@/entities/governance";
import { useProposalLifecycle } from "@/entities/governance";

interface ProposalActionsProps {
  proposal: Proposal;
}

export const ProposalActions = ({ proposal }: ProposalActionsProps) => {
  const { queue, execute, cancel, isProposer, isProcessing } =
    useProposalLifecycle(proposal);
  const [timeUntilExecute, setTimeUntilExecute] = useState<string>("");

  useEffect(() => {
    if (proposal.state === ProposalState.Queued && proposal.eta) {
      const updateTimer = () => {
        const now = Math.floor(Date.now() / 1000);
        const eta = Number(proposal.eta);
        const diff = eta - now;

        if (diff <= 0) {
          setTimeUntilExecute("Ready to execute");
        } else {
          const days = Math.floor(diff / 86400);
          const hours = Math.floor((diff % 86400) / 3600);
          const minutes = Math.floor((diff % 3600) / 60);
          const seconds = diff % 60;

          if (days > 0) {
            setTimeUntilExecute(`${days}d ${hours}h ${minutes}m`);
          } else if (hours > 0) {
            setTimeUntilExecute(`${hours}h ${minutes}m ${seconds}s`);
          } else if (minutes > 0) {
            setTimeUntilExecute(`${minutes}m ${seconds}s`);
          } else {
            setTimeUntilExecute(`${seconds}s`);
          }
        }
      };

      updateTimer();
      const interval = setInterval(updateTimer, 1000);

      return () => clearInterval(interval);
    }
  }, [proposal.state, proposal.eta]);

  const showQueue = canQueue(proposal.state);
  const showExecute = canExecute(proposal.state, proposal.eta);
  const showCancel = canCancel(proposal.state) && isProposer;

  if (!showQueue && !showExecute && !showCancel) {
    return null;
  }

  return (
    <Card className="bg-white-7 gap-3 rounded-[20px] md:rounded-4xl lg:gap-4">
      <CardHeader>
        <CardTitle className="text-content-100 text-base font-semibold sm:text-lg lg:text-xl">
          Proposal Actions
        </CardTitle>
        <CardDescription className="text-content-70 text-sm">
          Manage the lifecycle of this proposal
        </CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {showQueue && (
          <Button onClick={queue} disabled={isProcessing} className="w-full">
            {isProcessing ? (
              <div className="flex items-center gap-2">
                Queuing
                <Spinner variant="ellipsis" size={16} />
              </div>
            ) : (
              "Queue Proposal"
            )}
          </Button>
        )}

        {showExecute && (
          <div className="flex flex-col gap-2">
            {timeUntilExecute && (
              <div className="text-content-70 text-center text-sm">
                {timeUntilExecute === "Ready to execute" ? (
                  <span className="text-success font-semibold">
                    {timeUntilExecute}
                  </span>
                ) : (
                  <>Time until execution: {timeUntilExecute}</>
                )}
              </div>
            )}
            <Button
              onClick={execute}
              disabled={isProcessing || timeUntilExecute !== "Ready to execute"}
              className="w-full"
            >
              {isProcessing ? (
                <div className="flex items-center gap-2">
                  Executing
                  <Spinner variant="ellipsis" size={16} />
                </div>
              ) : (
                "Execute Proposal"
              )}
            </Button>
          </div>
        )}

        {showCancel && (
          <Button
            onClick={cancel}
            disabled={isProcessing}
            variant="destructive"
            className="h-12 flex-1 rounded-[100px] py-3 text-base font-semibold"
          >
            {isProcessing ? (
              <div className="flex items-center gap-2">
                Canceling
                <Spinner variant="ellipsis" size={16} />
              </div>
            ) : (
              "Cancel Proposal"
            )}
          </Button>
        )}
      </CardContent>
    </Card>
  );
};
