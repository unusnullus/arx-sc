"use client";

import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@arx/ui/components";
import { Badge } from "@arx/ui/components";
import { Proposal } from "@/entities/governance";
import {
  getProposalStateLabel,
  formatProposalId,
} from "@/entities/governance/utils";
import { decodeCalldata } from "@/entities/governance/utils/decode-calldata";

interface ProposalDetailsProps {
  proposal: Proposal;
}

const getStateBadgeVariant = (state: Proposal["state"]) => {
  switch (state) {
    case 1: // Active
      return "default";
    case 4: // Succeeded
      return "secondary";
    case 7: // Executed
      return "secondary";
    case 2: // Canceled
    case 3: // Defeated
      return "destructive";
    default:
      return "outline";
  }
};

export const ProposalDetails = ({ proposal }: ProposalDetailsProps) => {
  const formatBlockToDate = (blockNumber: bigint) => {
    const estimatedTimestamp = Date.now() + Number(blockNumber) * 12 * 1000;
    return new Date(estimatedTimestamp).toLocaleString();
  };

  return (
    <Card className="bg-white-7 w-full gap-3 rounded-[20px] md:rounded-4xl lg:gap-4">
      <CardHeader>
        <div className="flex items-start justify-between gap-4">
          <div className="flex-1">
            <CardTitle className="text-content-100 mb-2 text-base font-semibold sm:text-lg lg:text-xl">
              Proposal {formatProposalId(proposal.id).slice(0, 6)}...
              {formatProposalId(proposal.id).slice(-4)}
            </CardTitle>
            <CardDescription className="text-content-70 text-sm">
              Created by {proposal.proposer.slice(0, 6)}...
              {proposal.proposer.slice(-4)}
            </CardDescription>
          </div>
          <Badge variant={getStateBadgeVariant(proposal.state)}>
            {getProposalStateLabel(proposal.state)}
          </Badge>
        </div>
      </CardHeader>
      <CardContent className="flex flex-col gap-6">
        <div>
          <h3 className="text-content-100 mb-2 text-sm font-semibold">
            Description
          </h3>
          <div className="text-content-70 bg-white-5 border-white-10 rounded-md border p-4 text-sm whitespace-pre-wrap">
            {proposal.description || "No description available"}
          </div>
        </div>

        <div>
          <h3 className="text-content-100 mb-2 text-sm font-semibold">
            Proposal Details
          </h3>
          <div className="grid grid-cols-1 gap-2 text-sm md:grid-cols-2 md:gap-4">
            <div className="flex items-center justify-between">
              <span className="text-content-70">Snapshot Block:</span>
              <span className="text-content-100 font-mono">
                {proposal.snapshot.toString()}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-content-70">Deadline Block:</span>
              <span className="text-content-100 font-mono">
                {proposal.deadline.toString()}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-content-70">Snapshot Date:</span>
              <span className="text-content-100">
                {formatBlockToDate(proposal.snapshot)}
              </span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-content-70">Deadline Date:</span>
              <span className="text-content-100">
                {formatBlockToDate(proposal.deadline)}
              </span>
            </div>
            {!!proposal.eta && (
              <div className="flex items-center justify-between">
                <span className="text-content-70">Execution ETA:</span>
                <span className="text-content-100">
                  {new Date(Number(proposal.eta) * 1000).toLocaleString()}
                </span>
              </div>
            )}
          </div>
        </div>

        <div>
          <h3 className="text-content-100 mb-2 text-sm font-semibold">
            Actions
          </h3>
          <div className="flex flex-col gap-2 text-sm">
            {proposal.targets.map((target: `0x${string}`, index: number) => {
              const calldata = proposal.calldatas[index];
              const decoded = calldata ? decodeCalldata(calldata) : null;
              const value = proposal.values[index] || BigInt(0);

              return (
                <div
                  key={index}
                  className="border-white-10 bg-white-5 rounded-md border p-3"
                >
                  <div className="text-content-100 mb-2 font-medium">
                    Target {index + 1}
                  </div>
                  <div className="text-content-70 mb-2 font-mono text-xs">
                    {target}
                  </div>
                  {value > 0 && (
                    <div className="text-content-70 mb-2 text-xs">
                      Value: {value.toString()} wei
                    </div>
                  )}
                  {decoded ? (
                    <div className="flex flex-col gap-1.5">
                      <div className="text-content-100 text-xs font-medium">
                        {decoded.contractName} - {decoded.functionName}
                      </div>
                      {decoded.args.length > 0 && (
                        <div className="border-white-10 flex flex-col gap-1 border-l-2 pl-2">
                          {decoded.args.map((arg, argIndex) => (
                            <div
                              key={argIndex}
                              className="text-content-70 text-xs"
                            >
                              <span className="font-medium">{arg.name}</span>
                              {`: ${arg.value}`}
                              <span className="text-content-50 ml-1">
                                ({arg.type})
                              </span>
                            </div>
                          ))}
                        </div>
                      )}
                      <details className="mt-1">
                        <summary className="text-content-50 hover:text-content-70 cursor-pointer text-xs">
                          Raw calldata
                        </summary>
                        <div className="text-content-50 mt-1 pl-2 font-mono text-xs break-all">
                          {calldata}
                        </div>
                      </details>
                    </div>
                  ) : (
                    <div className="text-content-50 font-mono text-xs break-all">
                      Calldata: {calldata?.slice(0, 66)}
                      {calldata && calldata.length > 66 ? "..." : ""}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      </CardContent>
    </Card>
  );
};
