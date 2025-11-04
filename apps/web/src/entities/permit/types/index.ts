export interface PermitParams {
  value: bigint;
  deadline: bigint;
  v: number;
  r: `0x${string}`;
  s: `0x${string}`;
}

export interface PermitSettings {
  slippage: number;
  approve: boolean;
}
