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
  return (
    <Select
      value={value === "all" ? "all" : value.toString()}
      onValueChange={(val) =>
        onChange(val === "all" ? "all" : (Number(val) as ProposalState))
      }
    >
      <SelectTrigger className="w-[180px]">
        <SelectValue placeholder="Filter by status" />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="all">All</SelectItem>
        {Object.values(ProposalState).map((state) => (
          <SelectItem key={state} value={state.toString()}>
            {getProposalStateLabel(state as unknown as ProposalState)}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
};
