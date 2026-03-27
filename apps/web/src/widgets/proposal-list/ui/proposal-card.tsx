"use client";

import Link from "next/link";

import { Card, CardContent, CardHeader, CardTitle } from "@arx/ui/components";
import { Badge } from "@arx/ui/components";
import { Proposal, getProposalStateLabel } from "@/entities/governance";
import { formatProposalId } from "@/entities/governance/utils";

interface ProposalCardProps {
  proposal: Proposal;
}

const getStateBadgeVariant = (state: Proposal["state"]) => {
  switch (state) {
    case 1:
      return "default";
    case 4:
      return "secondary";
    case 7:
      return "secondary";
    case 2:
    case 3:
      return "destructive";
    default:
      return "outline";
  }
};

export const ProposalCard = ({ proposal }: ProposalCardProps) => {
  const descriptionPreview = proposal.description
    .split("\n")[0]
    .replace(/^#+\s*/, "")
    .slice(0, 100);

  const formatBlockToDate = (blockNumber: bigint) => {
    const estimatedTimestamp = Date.now() + Number(blockNumber) * 12 * 1000;
    return new Date(estimatedTimestamp).toLocaleDateString();
  };

  return (
    <Link href={`/governor/${proposal.id.toString()}`}>
      <Card className="bg-white-7 hover:bg-white-10 border-white-10 cursor-pointer gap-3 rounded-[20px] transition-colors md:rounded-4xl lg:gap-4">
        <CardHeader>
          <div className="flex items-start justify-between gap-4">
            <CardTitle className="text-content-100 line-clamp-2 text-base font-semibold sm:text-lg lg:text-xl">
              {`Proposal ${formatProposalId(proposal.id).slice(0, 6)}...${formatProposalId(proposal.id).slice(-4)}`}
            </CardTitle>
            <Badge variant={getStateBadgeVariant(proposal.state)}>
              {getProposalStateLabel(proposal.state)}
            </Badge>
          </div>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          <div className="text-content-70 text-sm">
            <p className="line-clamp-2">
              {descriptionPreview || "No description available"}
            </p>
          </div>

          <div className="border-white-10 text-content-50 flex flex-wrap items-center gap-4 border-t pt-4 text-xs">
            <div>
              <span className="font-medium">ID:</span>{" "}
              {formatProposalId(proposal.id).slice(0, 6)}...
              {formatProposalId(proposal.id).slice(-4)}
            </div>
            <div>
              <span className="font-medium">Snapshot:</span>{" "}
              {formatBlockToDate(proposal.snapshot)}
            </div>
            <div>
              <span className="font-medium">Deadline:</span>{" "}
              {formatBlockToDate(proposal.deadline)}
            </div>
            <div>
              <span className="font-medium">Proposer:</span>{" "}
              <span className="font-mono">
                {proposal.proposer.slice(0, 6)}...{proposal.proposer.slice(-4)}
              </span>
            </div>
          </div>
        </CardContent>
      </Card>
    </Link>
  );
};
