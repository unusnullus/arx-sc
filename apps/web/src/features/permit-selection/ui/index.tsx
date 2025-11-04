"use client";

import { memo, useCallback } from "react";

import { Settings2 } from "lucide-react";

import {
  Button,
  NumberInput,
  Popover,
  PopoverContent,
  PopoverTrigger,
  Switch,
} from "@arx/ui/components";
import { PermitSettings } from "@/entities/permit";

export const PermitSelectionBase = ({
  settings,
  updateSettings,
}: {
  settings: PermitSettings;
  updateSettings: (settings: PermitSettings) => void;
}) => {
  const handleSlippageChange = useCallback(
    (value?: number) => {
      updateSettings({ ...settings, slippage: value ?? 0 });
    },
    [settings, updateSettings],
  );

  const handleApproveChange = useCallback(
    (value: boolean) => {
      updateSettings({ ...settings, approve: value });
    },
    [settings, updateSettings],
  );

  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          aria-label="Open permit settings"
          aria-haspopup="dialog"
        >
          <Settings2 className="text-content-70 size-5" aria-hidden="true" />
        </Button>
      </PopoverTrigger>
      <PopoverContent
        className="flex flex-col gap-3"
        role="dialog"
        aria-labelledby="permit-title"
        aria-describedby="permit-description"
      >
        <span
          id="permit-title"
          className="text-base-primary text-sm font-medium lg:text-lg lg:font-semibold"
        >
          Permit
        </span>
        <p
          id="permit-description"
          className="text-content-70 text-xs lg:text-sm"
        >
          Allowance and slippage settings for permit transactions.
        </p>
        <div className="flex items-center gap-2">
          <label
            htmlFor="slippage-input"
            className="text-content-70 w-full text-xs lg:text-sm"
          >
            Slippage
          </label>
          <NumberInput
            id="slippage-input"
            value={settings.slippage}
            onChange={handleSlippageChange}
            aria-label="Slippage percentage"
            min={0}
            max={100}
            className="max-w-20"
          />
        </div>
        <div className="flex items-center gap-2">
          <label
            htmlFor="approve-switch"
            className="text-content-70 w-full text-xs lg:text-sm"
          >
            Approve
          </label>
          <Switch
            id="approve-switch"
            checked={settings.approve}
            onCheckedChange={handleApproveChange}
            aria-label="Enable approve and deposit in one transaction"
          />
        </div>
      </PopoverContent>
    </Popover>
  );
};

export const PermitSelection = memo(PermitSelectionBase);
