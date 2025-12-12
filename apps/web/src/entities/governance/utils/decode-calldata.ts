import { decodeFunctionData, formatUnits, isAddress, type Abi } from "viem";
import {
  ARX_ABI,
  ARX_TOKEN_SALE_ABI,
  ARX_ZAP_ROUTER_ABI,
  ARX_ZAPPER_ABI,
  GOVERNOR_ABI,
  RATE_POOL_ABI,
  ERC20_ABI,
} from "@arx/abi";

const KNOWN_ABIS: Array<{ name: string; abi: Abi }> = [
  { name: "ARX Token", abi: ARX_ABI as unknown as Abi },
  { name: "Token Sale", abi: ARX_TOKEN_SALE_ABI as unknown as Abi },
  { name: "Zap Router", abi: ARX_ZAP_ROUTER_ABI as unknown as Abi },
  { name: "Zapper", abi: ARX_ZAPPER_ABI as unknown as Abi },
  { name: "Governor", abi: GOVERNOR_ABI as unknown as Abi },
  { name: "Rate Pool", abi: RATE_POOL_ABI as unknown as Abi },
  { name: "ERC20", abi: ERC20_ABI as unknown as Abi },
];

export interface DecodedCalldata {
  contractName: string;
  functionName: string;
  args: Array<{ name: string; value: string; type: string }>;
  raw: string;
}

const formatValue = (value: unknown, type: string): string => {
  if (typeof value === "bigint") {
    if (type.includes("uint") && value > BigInt(1000)) {
      try {
        const formatted = formatUnits(value, 6);
        if (parseFloat(formatted) < 1000000) {
          return `${formatted} ARX`;
        }
        const formatted18 = formatUnits(value, 18);
        if (parseFloat(formatted18) < 1000000) {
          return `${formatted18} tokens`;
        }
      } catch {}
    }
    return value.toString();
  }
  if (typeof value === "string" && isAddress(value)) {
    return `${value.slice(0, 6)}...${value.slice(-4)}`;
  }
  if (Array.isArray(value)) {
    return `[${value.map((v) => formatValue(v, type)).join(", ")}]`;
  }
  return String(value);
};

export const decodeCalldata = (
  calldata: `0x${string}`,
): DecodedCalldata | null => {
  if (!calldata || calldata === "0x" || calldata.length < 10) {
    return null;
  }

  for (const { name, abi } of KNOWN_ABIS) {
    try {
      const decoded = decodeFunctionData({
        abi,
        data: calldata,
      });

      const functionAbi = abi.find(
        (item) =>
          item.type === "function" && item.name === decoded.functionName,
      ) as { inputs: Array<{ name: string; type: string }> } | undefined;

      if (!functionAbi || !decoded.args) {
        continue;
      }

      const args = functionAbi.inputs.map((input, index) => ({
        name: input.name || `arg${index}`,
        value: formatValue(decoded.args?.[index], input.type),
        type: input.type,
      }));

      return {
        contractName: name,
        functionName: decoded.functionName,
        args,
        raw: calldata,
      };
    } catch {
      continue;
    }
  }

  return null;
};
