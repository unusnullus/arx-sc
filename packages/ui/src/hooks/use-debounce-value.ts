import { useEffect, useState } from "react";

/**
 * Hook that debounces a value with a configurable delay
 * @param value - The value to debounce
 * @param delay - The delay in milliseconds (default: 500)
 * @returns The debounced value
 */
export function useDebounceValue<T>(value: T, delay: number = 500): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(handler);
    };
  }, [value, delay]);

  return debouncedValue;
}
