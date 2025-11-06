"use client";

import { useCallback, useEffect } from "react";

import { useConnectModal } from "@rainbow-me/rainbowkit";
import { toast } from "@arx/ui/components";
import { useAccount, useConnect, useDisconnect } from "wagmi";

export const useConnectWallet = () => {
  const { isConnected, address, isConnecting, isReconnecting } = useAccount();
  const {
    connect,
    connectors,
    error: connectError,
    isPending,
    isError,
  } = useConnect();
  const { disconnect } = useDisconnect();
  const { openConnectModal, connectModalOpen } = useConnectModal();

  useEffect(() => {
    if (connectError || isError) {
      const errorMessage = connectError?.message || "Failed to connect wallet";
      toast.error(errorMessage);
    }
  }, [connectError, isError]);

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

  const handleDisconnect = useCallback(() => {
    try {
      disconnect();
      toast.success("Wallet disconnected");
    } catch (err) {
      const errorMessage =
        err instanceof Error ? err.message : "Failed to disconnect wallet";
      toast.error(errorMessage);
    }
  }, [disconnect]);

  const checkConnection = useCallback(() => {
    if (!isConnected) {
      handleConnect();
    }

    return isConnected;
  }, [isConnected, handleConnect]);

  return {
    isConnected,
    address,
    isConnecting,
    isPending,
    isError,
    connectModalOpen,
    handleConnect,
    handleDisconnect,
    checkConnection,
    isLoading: isConnecting || isReconnecting || isPending,
  };
};
