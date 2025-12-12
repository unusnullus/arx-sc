/**
 * ProposalState enum values from OpenZeppelin Governor
 * Corresponds to enum IGovernor.ProposalState
 */
export enum ProposalState {
  Pending,
  Active,
  Canceled,
  Defeated,
  Succeeded,
  Queued,
  Expired,
  Executed,
}

/**
 * Vote type for casting votes
 * 0 = Against, 1 = For, 2 = Abstain
 */
export enum VoteType {
  Against = 0,
  For = 1,
  Abstain = 2,
}

/**
 * Proposal data structure
 */
export interface Proposal {
  id: bigint;
  proposer: `0x${string}`;
  targets: readonly `0x${string}`[];
  values: readonly bigint[];
  calldatas: readonly `0x${string}`[];
  description: string;
  descriptionHash: `0x${string}`;
  state: ProposalState;
  snapshot: bigint;
  deadline: bigint;
  eta?: bigint;
}

/**
 * Voting results for a proposal
 */
export interface ProposalVotes {
  againstVotes: bigint;
  forVotes: bigint;
  abstainVotes: bigint;
}

/**
 * Governor configuration
 */
export interface GovernorConfig {
  proposalThreshold: bigint;
  votingDelay: bigint;
  votingPeriod: bigint;
  quorumNumerator: bigint;
  quorumDenominator: bigint;
}
