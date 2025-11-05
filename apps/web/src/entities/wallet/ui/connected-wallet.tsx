"use client";

import { useState } from "react";

import { ChevronDown, LogOut } from "lucide-react";

import { cn } from "@arx/ui/lib";
import {
  Button,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@arx/ui/components";

export const ConnectedWallet = ({
  address,
  className,
  onDisconnect,
}: {
  address: string;
  className?: string;
  onDisconnect?: () => void;
}) => {
  const [open, setOpen] = useState(false);

  const handleOpenChange = () => {
    setOpen((open) => !open);
  };

  const handleDisconnect = () => {
    if (onDisconnect) {
      onDisconnect();
    }
  };

  return (
    <DropdownMenu open={open} onOpenChange={handleOpenChange}>
      <DropdownMenuTrigger asChild className={className}>
        <Button className="w-36">
          <div className="flex items-center justify-center gap-2">
            <span>
              {address.slice(0, 6)}...{address.slice(-4)}
            </span>
            <ChevronDown
              className={cn("text-t-primary h-4 w-4 transition", {
                "rotate-180": open,
              })}
            />
          </div>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent className="w-36">
        <DropdownMenuItem className="cursor-pointer" onClick={handleDisconnect}>
          <div className="flex flex-1 items-center justify-center gap-2">
            <LogOut className="h-4 w-4" />
            <span>Disconnect</span>
          </div>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
};
