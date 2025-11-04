import { useCallback } from "react";

import { useConnectModal } from "@rainbow-me/rainbowkit";
import { useAccount, useConnect } from "wagmi";
import { toast } from "@arx/ui/components";

export const useConnectionCheck = () => {
  const { isConnected, address } = useAccount();
  const { openConnectModal } = useConnectModal();
  const { connect, connectors } = useConnect();

  const handleConnect = useCallback(async () => {
    try {
      if (openConnectModal) {
        openConnectModal();
      } else {
        const connector = connectors[0];
        if (connector) {
          await connect({ connector });
        } else {
          throw new Error("No wallet connectors available");
        }
      }
    } catch (err) {
      const errorMessage =
        err instanceof Error ? err.message : "Failed to connect wallet";
      toast.error(errorMessage);
    }
  }, [connectors, connect, openConnectModal]);

  const checkConnection = useCallback(() => {
    if (!isConnected) {
      handleConnect();
    }

    return isConnected;
  }, [isConnected, handleConnect]);

  return {
    address: address as `0x${string}`,
    isConnected,
    checkConnection,
  };
};
