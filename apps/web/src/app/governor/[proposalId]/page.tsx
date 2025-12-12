"use client";

import { useParams } from "next/navigation";
import Link from "next/link";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Spinner,
} from "@arx/ui/components";
import { ProposalDetails, VotingResults } from "@/widgets/proposal-details";
import { VoteButtons } from "@/features/vote-proposal";
import {
  useProposalDetails,
  ProposalState,
  canVote,
} from "@/entities/governance";

export default function ProposalPage() {
  const params = useParams();
  const proposalId = BigInt(params.proposalId as string);

  const { proposal, votes, quorum, isLoading } = useProposalDetails(proposalId);

  if (isLoading) {
    return (
      <div className="grid grid-cols-1 gap-4 px-4 md:grid-cols-2 md:px-0">
        <div className="flex items-center justify-center py-12 md:col-span-2">
          <Spinner variant="circle" />
        </div>
      </div>
    );
  }

  if (!proposal) {
    return (
      <div className="grid grid-cols-1 gap-4 px-4 md:grid-cols-2 md:px-0">
        <div className="text-error border-white-10 rounded-lg border p-6 text-center md:col-span-2">
          Proposal not found
        </div>
      </div>
    );
  }

  return (
    <div className="grid w-full grid-cols-1 gap-4 px-4 md:grid-cols-2 md:px-0">
      <div className="md:col-span-2">
        <Link
          href="/governor"
          className="text-content-70 hover:text-content-100 mb-4 inline-block text-sm transition-colors"
        >
          ← Back to Proposals
        </Link>
      </div>

      <div className="flex flex-1">
        <ProposalDetails proposal={proposal} />
      </div>

      {votes && (
        <div className="flex flex-col gap-4">
          <VotingResults votes={votes} quorum={quorum} />
          {proposal.state === ProposalState.Active && (
            <div>
              <Card className="bg-white-7 gap-3 rounded-[20px] md:rounded-4xl lg:gap-4">
                <CardHeader>
                  <CardTitle className="text-content-100 text-base font-semibold sm:text-lg lg:text-xl">
                    Cast Your Vote
                  </CardTitle>
                  <CardDescription className="text-content-70 text-sm">
                    Vote on this proposal. Your vote will be recorded on-chain.
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <VoteButtons
                    proposalId={proposalId}
                    canVote={canVote(proposal.state)}
                  />
                </CardContent>
              </Card>
            </div>
          )}
        </div>
      )}

      {/* <div>
        <ProposalActions proposal={proposal} />
      </div> */}
    </div>
  );
}
