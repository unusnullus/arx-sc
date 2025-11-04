"use client";

import { useEffect, useState } from "react";

import { cn } from "@arx/ui/lib";

import { Input } from "./input";

interface NumberInputProps
  extends Omit<React.ComponentProps<"input">, "type" | "onChange"> {
  value?: number;
  onChange?: (value: number | undefined) => void;
  min?: number;
  max?: number;
  step?: number;
  maxDecimals?: number;
}

export const NumberInput = ({
  className,
  value,
  onChange,
  min = 0,
  max = 100,
  step = 0.01,
  maxDecimals = 2,
  ...props
}: NumberInputProps) => {
  const [inputValue, setInputValue] = useState(
    value !== undefined ? value.toString() : "",
  );

  useEffect(() => {
    setInputValue(value !== undefined ? value.toString() : "");
  }, [value]);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const rawValue = e.target.value;

    if (rawValue === "") {
      setInputValue("");
      onChange?.(undefined);
      return;
    }

    const decimalPattern = new RegExp(`^\\d*(\\.\\d{0,${maxDecimals}})?$`);
    if (!decimalPattern.test(rawValue)) {
      return;
    }

    const numValue = parseFloat(rawValue);

    if (!isNaN(numValue) && numValue >= min && numValue <= max) {
      setInputValue(rawValue);
      onChange?.(numValue);
    } else if (rawValue === "" || rawValue === ".") {
      setInputValue(rawValue);
    }
  };

  const handleBlur = () => {
    if (inputValue === "" || inputValue === ".") {
      setInputValue("");
      onChange?.(undefined);
    } else {
      const numValue = parseFloat(inputValue);
      if (!isNaN(numValue)) {
        const clampedValue = Math.max(min, Math.min(max, numValue));
        const formattedValue = Number(clampedValue.toFixed(maxDecimals));
        setInputValue(formattedValue.toString());
        onChange?.(formattedValue);
      }
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if ([8, 9, 27, 13, 46, 35, 36, 37, 39].includes(e.keyCode)) {
      return;
    }

    if ((e.ctrlKey || e.metaKey) && [65, 67, 86, 88].includes(e.keyCode)) {
      return;
    }

    if (
      (e.keyCode >= 48 && e.keyCode <= 57) ||
      e.keyCode === 190 ||
      e.keyCode === 110
    ) {
      if (
        (e.keyCode === 190 || e.keyCode === 110) &&
        inputValue.includes(".")
      ) {
        e.preventDefault();
        return;
      }

      if (inputValue.includes(".")) {
        const decimalPart = inputValue.split(".")[1];
        if (decimalPart && decimalPart.length >= maxDecimals) {
          e.preventDefault();
          return;
        }
      }

      return;
    }

    e.preventDefault();
  };

  return (
    <Input
      type="text"
      inputMode="decimal"
      value={inputValue}
      onChange={handleChange}
      onBlur={handleBlur}
      onKeyDown={handleKeyDown}
      min={min}
      max={max}
      step={step}
      className={cn(className)}
      {...props}
    />
  );
};
