"use client";

import { VotingPowerCard } from "@/widgets/governance-voting-power";
import { CreateProposalForm } from "@/features/create-proposal";
import { ProposalList } from "@/widgets/proposal-list";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@arx/ui/components";

export default function GovernorPage() {
  return (
    <div className="grid w-full grid-cols-1 gap-4 px-4 md:grid-cols-2 md:px-0">
      <VotingPowerCard />
      <Card className="bg-white-7 gap-4 rounded-[20px] py-2 md:rounded-4xl md:py-6">
        <CardHeader className="px-2 md:px-6">
          <CardTitle className="text-content-100 text-base font-semibold sm:text-lg lg:text-xl">
            Create Proposal
          </CardTitle>
          <CardDescription className="text-content-70 text-base">
            Create a new governance proposal to be voted on by the community
          </CardDescription>
        </CardHeader>
        <CardContent className="px-2 md:px-6">
          <CreateProposalForm />
        </CardContent>
      </Card>
      <div className="md:col-span-2">
        <ProposalList />
      </div>
    </div>
  );
}
