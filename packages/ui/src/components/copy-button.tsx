"use client";

import { memo, useCallback, useState } from "react";

import { Check, Copy } from "lucide-react";

import { Button } from "./button";
import { Tooltip, TooltipContent, TooltipTrigger } from "./tooltip";

const CopyButtonBase = ({
  text,
  tooltip,
}: {
  text: string;
  tooltip: string;
}) => {
  const [copied, setCopied] = useState(false);

  const handleCopy = useCallback(() => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }, [text]);

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button variant="outline" size="icon" onClick={handleCopy}>
          {copied ? (
            <Check className="h-3 w-3 text-green-500" aria-hidden="true" />
          ) : (
            <Copy className="h-3 w-3" aria-hidden="true" />
          )}
        </Button>
      </TooltipTrigger>
      <TooltipContent>{copied ? "Copied" : tooltip}</TooltipContent>
    </Tooltip>
  );
};

export const CopyButton = memo(CopyButtonBase);
