"use client";

import { useState, useMemo } from "react";

import { useProposals } from "@/entities/governance";
import {
  ProposalStatusFilter,
  type ProposalStatusFilterType,
} from "@/features/proposal-filters";
import { ProposalCard } from "./proposal-card";
import { Card, CardContent, Spinner } from "@arx/ui/components";

export const ProposalList = () => {
  const { proposals, isLoading, error } = useProposals();
  const [filter, setFilter] = useState<ProposalStatusFilterType>("all");

  const filteredProposals = useMemo(() => {
    if (filter === "all") {
      return proposals;
    }
    return proposals.filter((p) => p.state === filter);
  }, [proposals, filter]);

  if (isLoading) {
    return (
      <Card className="bg-white-7 gap-3 rounded-[20px] md:rounded-4xl lg:gap-4">
        <CardContent className="flex items-center justify-center py-12">
          <Spinner variant="circle" />
        </CardContent>
      </Card>
    );
  }

  if (error) {
    return (
      <Card className="bg-white-7 gap-3 rounded-[20px] md:rounded-4xl lg:gap-4">
        <CardContent className="text-error py-6 text-center">
          Error loading proposals: {error.message}
        </CardContent>
      </Card>
    );
  }

  if (proposals.length === 0) {
    return (
      <Card className="bg-white-7 gap-3 rounded-[20px] md:rounded-4xl lg:gap-4">
        <CardContent className="text-content-50 py-6 text-center">
          No proposals found
        </CardContent>
      </Card>
    );
  }

  console.log(filteredProposals);
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <h2 className="text-content-100 text-base font-semibold sm:text-lg lg:text-xl">
          Proposals ({filteredProposals.length})
        </h2>
        <ProposalStatusFilter value={filter} onChange={setFilter} />
      </div>

      <div className="flex flex-col gap-4">
        {filteredProposals.map((proposal) => (
          <ProposalCard key={proposal.id.toString()} proposal={proposal} />
        ))}
      </div>
    </div>
  );
};
