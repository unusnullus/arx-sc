import { ProposalState, ProposalVotes } from "../types";

/**
 * Parse proposal state from uint8 to ProposalState enum
 */
export function parseProposalState(state: number): ProposalState {
  if (state >= 0 && state <= 7) {
    return state as ProposalState;
  }
  throw new Error(`Invalid proposal state: ${state}`);
}

/**
 * Format proposal ID for display
 */
export function formatProposalId(proposalId: bigint | string): string {
  const id = typeof proposalId === "string" ? BigInt(proposalId) : proposalId;
  return id.toString();
}

/**
 * Get human-readable label for proposal state
 */
export function getProposalStateLabel(state: ProposalState): string {
  switch (state) {
    case ProposalState.Pending:
      return "Pending";
    case ProposalState.Active:
      return "Active";
    case ProposalState.Canceled:
      return "Canceled";
    case ProposalState.Defeated:
      return "Defeated";
    case ProposalState.Succeeded:
      return "Succeeded";
    case ProposalState.Queued:
      return "Queued";
    case ProposalState.Expired:
      return "Expired";
    case ProposalState.Executed:
      return "Executed";
    default:
      return "Unknown";
  }
}

/**
 * Calculate quorum progress percentage
 * @param votes Total votes (for + against + abstain)
 * @param quorum Required quorum
 * @returns Progress percentage (0-100)
 */
export function calculateQuorumProgress(
  votes: ProposalVotes,
  quorum: bigint,
): number {
  const totalVotes = votes.forVotes + votes.againstVotes + votes.abstainVotes;

  if (quorum === BigInt(0)) return 0;
  if (totalVotes === BigInt(0)) return 0;

  const progress = Number((totalVotes * BigInt(10000)) / quorum) / 100;
  return Math.min(progress, 100);
}

/**
 * Calculate vote percentages
 */
export function calculateVotePercentages(votes: ProposalVotes): {
  forPercent: number;
  againstPercent: number;
  abstainPercent: number;
} {
  const total = votes.forVotes + votes.againstVotes + votes.abstainVotes;

  if (total === BigInt(0)) {
    return {
      forPercent: 0,
      againstPercent: 0,
      abstainPercent: 0,
    };
  }

  const forPercent = Number((votes.forVotes * BigInt(10000)) / total) / 100;
  const againstPercent =
    Number((votes.againstVotes * BigInt(10000)) / total) / 100;
  const abstainPercent =
    Number((votes.abstainVotes * BigInt(10000)) / total) / 100;

  return {
    forPercent,
    againstPercent,
    abstainPercent,
  };
}

/**
 * Format block number to human-readable date
 */
export function formatBlockToDate(
  blockNumber: bigint,
  blockTime: number = 12,
): Date {
  const timestamp = Date.now() + Number(blockNumber) * blockTime * 1000;
  return new Date(timestamp);
}

/**
 * Check if proposal can be voted on
 */
export function canVote(state: ProposalState): boolean {
  return state === ProposalState.Active;
}

/**
 * Check if proposal can be queued
 */
export function canQueue(state: ProposalState): boolean {
  return state === ProposalState.Succeeded;
}

/**
 * Check if proposal can be executed
 */
export function canExecute(state: ProposalState, eta?: bigint): boolean {
  if (state !== ProposalState.Queued) return false;
  if (!eta) return false;
  return Date.now() / 1000 >= Number(eta);
}

/**
 * Check if proposal can be canceled
 */
export function canCancel(state: ProposalState): boolean {
  return state === ProposalState.Pending || state === ProposalState.Active;
}
