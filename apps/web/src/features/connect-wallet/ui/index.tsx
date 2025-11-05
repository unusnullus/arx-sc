"use client";

import { WalletButton, WalletInfo, useConnectWallet } from "@/entities/wallet";

export const ConnectWallet = ({
  className,
  idle,
}: {
  className?: string;
  idle?: boolean;
}) => {
  const { isConnected, address, handleConnect, handleDisconnect, isLoading } =
    useConnectWallet();

  if (idle && isConnected) {
    return null;
  }

  if (isConnected && address) {
    return <WalletInfo address={address} onDisconnect={handleDisconnect} />;
  }

  return (
    <WalletButton
      onClick={handleConnect}
      className={className}
      isLoading={isLoading}
    />
  );
};
