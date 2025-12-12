"use client";

import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@arx/ui/components";
import { ProposalVotes } from "@/entities/governance";
import { formatUnits } from "viem";
import {
  calculateQuorumProgress,
  calculateVotePercentages,
} from "@/entities/governance/utils";

interface VotingResultsProps {
  votes: ProposalVotes;
  quorum?: bigint;
}

export const VotingResults = ({ votes, quorum }: VotingResultsProps) => {
  const totalVotes = votes.forVotes + votes.againstVotes + votes.abstainVotes;
  const percentages = calculateVotePercentages(votes);
  const quorumProgress = quorum ? calculateQuorumProgress(votes, quorum) : 0;

  return (
    <Card className="bg-white-7 gap-3 rounded-[20px] md:rounded-4xl lg:gap-4">
      <CardHeader>
        <CardTitle className="text-content-100 text-base font-semibold sm:text-lg lg:text-xl">
          Voting Results
        </CardTitle>
        <CardDescription className="text-content-70 text-sm">
          Current voting statistics
        </CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-6">
        <div className="flex flex-col gap-4">
          <div>
            <div className="mb-2 flex items-center justify-between text-sm">
              <span className="text-content-70">For</span>
              <span className="text-content-100 font-semibold">
                {formatUnits(votes.forVotes, 6)} ARX (
                {percentages.forPercent.toFixed(2)}%)
              </span>
            </div>
            <div className="bg-white-5 h-2 w-full overflow-hidden rounded-full">
              <div
                className="bg-success h-full transition-all"
                style={{ width: `${percentages.forPercent}%` }}
              />
            </div>
          </div>

          <div>
            <div className="mb-2 flex items-center justify-between text-sm">
              <span className="text-content-70">Against</span>
              <span className="text-content-100 font-semibold">
                {formatUnits(votes.againstVotes, 6)} ARX (
                {percentages.againstPercent.toFixed(2)}%)
              </span>
            </div>
            <div className="bg-white-5 h-2 w-full overflow-hidden rounded-full">
              <div
                className="bg-error h-full transition-all"
                style={{ width: `${percentages.againstPercent}%` }}
              />
            </div>
          </div>

          <div>
            <div className="mb-2 flex items-center justify-between text-sm">
              <span className="text-content-70">Abstain</span>
              <span className="text-content-100 font-semibold">
                {formatUnits(votes.abstainVotes, 6)} ARX (
                {percentages.abstainPercent.toFixed(2)}%)
              </span>
            </div>
            <div className="bg-white-5 h-2 w-full overflow-hidden rounded-full">
              <div
                className="bg-content-50 h-full transition-all"
                style={{ width: `${percentages.abstainPercent}%` }}
              />
            </div>
          </div>
        </div>

        {quorum && (
          <div>
            <div className="mb-2 flex items-center justify-between text-sm">
              <span className="text-content-70">Quorum Progress</span>
              <span className="text-content-100 font-semibold">
                {formatUnits(totalVotes, 6)} / {formatUnits(quorum, 6)} ARX (
                {quorumProgress.toFixed(2)}%)
              </span>
            </div>
            <div className="bg-white-5 h-2 w-full overflow-hidden rounded-full">
              <div
                className="bg-primary h-full transition-all"
                style={{ width: `${Math.min(quorumProgress, 100)}%` }}
              />
            </div>
          </div>
        )}

        <div className="border-white-10 text-content-70 border-t pt-4 text-sm">
          Total Votes: {formatUnits(totalVotes, 6)} ARX
        </div>
      </CardContent>
    </Card>
  );
};
