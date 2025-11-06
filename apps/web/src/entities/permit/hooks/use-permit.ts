"use client";

import { useCallback, useState } from "react";

import { toast } from "@arx/ui/components";
import { parseUnits } from "viem";
import {
  useAccount,
  useReadContract,
  useReadContracts,
  useSignTypedData,
} from "wagmi";

import { Token, isNativeToken } from "@arx/config";
import { ERC20_ABI } from "@arx/abi";
import { PermitParams } from "../types";

export const usePermit = (token?: Token | null) => {
  const { address, chainId } = useAccount();
  const [isLoading, setIsLoading] = useState(false);
  const { signTypedDataAsync } = useSignTypedData();

  const enabled =
    !!chainId &&
    !!address &&
    !!token &&
    !!token.address &&
    !isNativeToken(token.address);

  const { data: metaData } = useReadContracts({
    contracts: [
      {
        address: token?.address,
        abi: ERC20_ABI,
        functionName: "name",
      },
      {
        address: token?.address,
        abi: ERC20_ABI,
        functionName: "version",
      },
    ],
    query: {
      enabled,
      select: (results) => {
        const name = results?.[0]?.result as string | undefined;
        const version = (results?.[1]?.result as string | undefined) ?? "1";
        return { name, version };
      },
    },
  });

  const { data: nonce, refetch: refetchNonce } = useReadContract({
    address: token?.address,
    abi: ERC20_ABI,
    functionName: "nonces",
    args: address ? [address] : undefined,
    query: { enabled },
  });

  const createPermit = useCallback(
    async (
      amount: string,
      spender: `0x${string}`,
    ): Promise<PermitParams | null> => {
      if (!enabled || !chainId || !address || !token?.address || !spender) {
        toast.error("Wallet not connected");
        return null;
      }

      if (isNativeToken(token.address)) {
        return null;
      }

      try {
        setIsLoading(true);

        const amountWei = parseUnits(amount, token.decimals);
        const deadline = BigInt(Math.floor(Date.now() / 1000) + 1800);

        const name = metaData?.name;
        const version = metaData?.version ?? "1";

        if (!name || !address) {
          toast.error("Permit failed");
          return null;
        }

        const domain = {
          name,
          version,
          chainId,
          verifyingContract: token.address,
        };

        const types = {
          Permit: [
            { name: "owner", type: "address" },
            { name: "spender", type: "address" },
            { name: "value", type: "uint256" },
            { name: "nonce", type: "uint256" },
            { name: "deadline", type: "uint256" },
          ],
        } as const;

        const { data: freshNonce } = await refetchNonce({
          throwOnError: false,
          cancelRefetch: false,
        });

        const nonceToUse = (freshNonce ?? nonce) as bigint | undefined;

        if (nonceToUse === null || nonceToUse === undefined) {
          toast.error("Permit failed");
          return null;
        }

        const message = {
          owner: address,
          spender,
          value: amountWei,
          nonce: nonceToUse,
          deadline,
        };

        const signature = await signTypedDataAsync({
          domain,
          types,
          primaryType: "Permit",
          message,
        });

        const r = `0x${signature.slice(2, 66)}` as `0x${string}`;
        const s = `0x${signature.slice(66, 130)}` as `0x${string}`;
        const v = parseInt(signature.slice(130, 132), 16);

        return {
          value: amountWei,
          deadline,
          v,
          r,
          s,
        };
      } catch (err) {
        const error = err as Error;
        console.error("Permit error:", error);
        toast.error("Permit failed");
        return null;
      } finally {
        setIsLoading(false);
      }
    },
    [
      address,
      chainId,
      enabled,
      metaData?.name,
      metaData?.version,
      nonce,
      refetchNonce,
      signTypedDataAsync,
      token?.address,
      token?.decimals,
    ],
  );

  return {
    createPermit,
    isLoading,
  };
};
