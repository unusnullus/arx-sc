"use client";

import { useState } from "react";
import { useMediaQuery } from "@arx/ui/hooks";
import {
  ResponsiveDialog,
  DialogFooter,
  Button,
  Textarea,
} from "@arx/ui/components";
import { VoteType } from "@/entities/governance";

interface VoteModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  voteType: VoteType;
  onVote: (reason?: string) => void;
  isVoting: boolean;
}

const getVoteTypeLabel = (voteType: VoteType): string => {
  switch (voteType) {
    case VoteType.For:
      return "For";
    case VoteType.Against:
      return "Against";
    case VoteType.Abstain:
      return "Abstain";
  }
};

export const VoteModal = ({
  open,
  onOpenChange,
  voteType,
  onVote,
  isVoting,
}: VoteModalProps) => {
  const [reason, setReason] = useState("");
  const isDesktop = useMediaQuery("(min-width: 768px)");

  const handleSubmit = () => {
    onVote(reason.trim() || undefined);
    setReason("");
    onOpenChange(false);
  };

  const handleCancel = () => {
    setReason("");
    onOpenChange(false);
  };

  return (
    <ResponsiveDialog
      open={open}
      onOpenChange={onOpenChange}
      title={`Vote ${getVoteTypeLabel(voteType)}`}
      description="Optionally provide a reason for your vote. This will be recorded on-chain."
      closeButtonText="Cancel"
    >
      <div className="flex flex-col gap-4 py-4">
        <div className="flex flex-col gap-2">
          <label className="text-content-70 text-sm font-medium">
            Reason (optional)
          </label>
          <Textarea
            className="text-content-100 placeholder:text-content-70 bg-white-5 border-white-10 focus-visible:border-white-15 focus-visible:ring-white-15/50 min-h-[120px] w-full rounded-md border px-4 py-3 text-sm"
            placeholder="Explain your vote (optional)..."
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            disabled={isVoting}
          />
        </div>
        {!isDesktop && (
          <div className="flex flex-col gap-2">
            <Button
              onClick={handleSubmit}
              disabled={isVoting}
              className="text-content-100 bg-white-10 hover:bg-white-15 h-12 w-full rounded-[100px] py-3 text-base font-semibold"
            >
              {isVoting ? "Submitting..." : "Submit Vote"}
            </Button>
          </div>
        )}
      </div>

      {isDesktop && (
        <DialogFooter className="gap-3">
          <Button
            variant="outline"
            onClick={handleCancel}
            disabled={isVoting}
            className="text-content-100 border-white-10 hover:bg-white-10 h-12 rounded-[100px] px-6 py-3 text-base font-semibold"
          >
            Cancel
          </Button>
          <Button
            onClick={handleSubmit}
            disabled={isVoting}
            className="text-content-100 bg-white-10 hover:bg-white-15 h-12 rounded-[100px] px-6 py-3 text-base font-semibold"
          >
            {isVoting ? "Submitting..." : "Submit Vote"}
          </Button>
        </DialogFooter>
      )}
    </ResponsiveDialog>
  );
};
