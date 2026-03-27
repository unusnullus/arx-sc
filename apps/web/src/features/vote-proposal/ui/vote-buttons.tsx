"use client";

import { useState } from "react";
import { Button } from "@arx/ui/components";
import { VoteType } from "@/entities/governance";
import { useVote } from "@/entities/governance";
import { VoteModal } from "./vote-modal";

interface VoteButtonsProps {
  proposalId: bigint;
  canVote: boolean;
}

export const VoteButtons = ({ proposalId, canVote }: VoteButtonsProps) => {
  const { castVote, isVoting, hasVoted } = useVote(proposalId);
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedVoteType, setSelectedVoteType] = useState<VoteType | null>(
    null,
  );

  const handleVoteClick = (voteType: VoteType) => {
    setSelectedVoteType(voteType);
    setModalOpen(true);
  };

  const handleVote = async (reason?: string) => {
    if (selectedVoteType === null) return;
    await castVote(selectedVoteType, reason);
  };

  if (hasVoted) {
    return (
      <div className="text-content-50 border-white-10 rounded-lg border p-4 text-center">
        You have already voted on this proposal
      </div>
    );
  }

  if (!canVote) {
    return (
      <div className="text-content-50 border-white-10 rounded-lg border p-4 text-center">
        Voting is not available for this proposal
      </div>
    );
  }

  return (
    <>
      <div className="flex flex-col gap-3 md:flex-row">
        <Button
          onClick={() => handleVoteClick(VoteType.For)}
          disabled={isVoting}
          className="text-content-100 bg-white-10 hover:bg-white-15 h-12 flex-1 rounded-[100px] py-3 text-base font-semibold"
        >
          Vote For
        </Button>
        <Button
          onClick={() => handleVoteClick(VoteType.Against)}
          disabled={isVoting}
          variant="destructive"
          className="h-12 flex-1 rounded-[100px] py-3 text-base font-semibold"
        >
          Vote Against
        </Button>
        <Button
          onClick={() => handleVoteClick(VoteType.Abstain)}
          disabled={isVoting}
          variant="outline"
          className="text-content-100 border-white-10 hover:bg-white-10 h-12 flex-1 rounded-[100px] py-3 text-base font-semibold"
        >
          Abstain
        </Button>
      </div>
      {selectedVoteType !== null && (
        <VoteModal
          open={modalOpen}
          onOpenChange={setModalOpen}
          voteType={selectedVoteType}
          onVote={handleVote}
          isVoting={isVoting}
        />
      )}
    </>
  );
};
