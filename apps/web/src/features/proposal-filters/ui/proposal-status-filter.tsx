"use client";

import { ProposalState } from "@/entities/governance";
import { getProposalStateLabel } from "@/entities/governance/utils";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@arx/ui/components";

export type ProposalStatusFilter = ProposalState | "all";

interface ProposalStatusFilterProps {
  value: ProposalStatusFilter;
  onChange: (value: ProposalStatusFilter) => void;
}

export const ProposalStatusFilter = ({
  value,
  onChange,
}: ProposalStatusFilterProps) => {
  const proposalStates = Object.values(ProposalState).filter(
    (state): state is ProposalState => typeof state === "number",
  );

  return (
    <Select
      value={value === "all" ? "all" : value.toString()}
      onValueChange={(val) =>
        onChange(val === "all" ? "all" : (Number(val) as ProposalState))
      }
    >
      <SelectTrigger className="bg-white-10 w-[180px]">
        <SelectValue placeholder="Filter by status">
          {value === "all"
            ? "All"
            : getProposalStateLabel(value as ProposalState)}
        </SelectValue>
      </SelectTrigger>
      <SelectContent className="max-h-[300px]">
        <SelectItem value="all">All</SelectItem>
        {proposalStates.map((state) => (
          <SelectItem key={state} value={state.toString()}>
            {getProposalStateLabel(state)}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
};
