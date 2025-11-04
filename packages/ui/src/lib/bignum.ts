import { formatEther, formatUnits, parseEther, parseUnits } from "viem";

/**
 * Type representing any value that can be converted to a BigInt
 * @typedef {string | number | bigint} BigNumberish
 */
export type BigNumberish = string | number | bigint;

/**
 * Parse a string representation of a number into wei (18 decimals)
 * @param value - String representation of the number to parse
 * @returns BigInt representation in wei
 * @throws Error if the value cannot be parsed
 * @example
 * ```typescript
 * parseWei('1.5') // Returns 1500000000000000000n
 * parseWei('0.001') // Returns 1000000000000000n
 * ```
 */
export const parseWei = (value: string): bigint => {
  return parseEther(value);
};

/**
 * Format wei to ether string with 18 decimal places
 * @param value - BigInt value in wei to format
 * @returns String representation with decimal places
 * @example
 * ```typescript
 * formatWei(1500000000000000000n) // Returns '1.5'
 * formatWei(1000000000000000n) // Returns '0.001'
 * ```
 */
export const formatWei = (value: BigNumberish): string => {
  return formatEther(BigInt(value));
};

/**
 * Parse a string representation of a number with specified decimals
 * @param value - String representation of the number to parse
 * @param decimals - Number of decimal places to use for parsing
 * @returns BigInt representation with the specified decimals
 * @throws Error if the value cannot be parsed or decimals is invalid
 * @example
 * ```typescript
 * parseUnitsSafe('1.5', 6) // Returns 1500000n (USDC)
 * parseUnitsSafe('0.001', 8) // Returns 100000n (WBTC)
 * ```
 */
export const parseUnitsSafe = (value: string, decimals: number): bigint => {
  try {
    return parseUnits(value, decimals);
  } catch (_) {
    throw new Error(
      `Failed to parse units: ${value} with ${decimals} decimals`,
    );
  }
};

/**
 * Format bigint to string with specified decimals
 * @param value - BigInt value to format
 * @param decimals - Number of decimal places to use for formatting
 * @returns String representation with the specified decimal places
 * @throws Error if the value cannot be formatted or decimals is invalid
 * @example
 * ```typescript
 * formatUnitsSafe(1500000n, 6) // Returns '1.5' (USDC)
 * formatUnitsSafe(100000n, 8) // Returns '0.001' (WBTC)
 * ```
 */
export const formatUnitsSafe = (
  value: BigNumberish,
  decimals: number,
): string => {
  try {
    return formatUnits(BigInt(value), decimals);
  } catch (_) {
    throw new Error(
      `Failed to format units: ${value} with ${decimals} decimals`,
    );
  }
};

/**
 * Safe addition for bigint values with error handling
 * @param a - First operand
 * @param b - Second operand
 * @returns Sum of a and b as BigInt
 * @throws Error if conversion or operation fails
 * @example
 * ```typescript
 * safeAdd('1000000000000000000', '500000000000000000') // Returns 1500000000000000000n
 * safeAdd(1.5, 0.5) // Returns 2n
 * ```
 */
export const safeAdd = (a: BigNumberish, b: BigNumberish): bigint => {
  try {
    return BigInt(a) + BigInt(b);
  } catch (_) {
    throw new Error(`Safe addition failed: ${a} + ${b}`);
  }
};

/**
 * Safe subtraction for bigint values with negative result protection
 * @param a - Minuend (value to subtract from)
 * @param b - Subtrahend (value to subtract)
 * @returns Difference of a and b as BigInt
 * @throws Error if result is negative or operation fails
 * @example
 * ```typescript
 * safeSub('2000000000000000000', '500000000000000000') // Returns 1500000000000000000n
 * safeSub('100', '50') // Returns 50n
 * ```
 */
export const safeSub = (a: BigNumberish, b: BigNumberish): bigint => {
  try {
    const result = BigInt(a) - BigInt(b);
    if (result < BigInt(0)) {
      throw new Error("Subtraction result is negative");
    }
    return result;
  } catch (_) {
    throw new Error(`Safe subtraction failed: ${a} - ${b}`);
  }
};

/**
 * Safe multiplication for bigint values with overflow protection
 * @param a - First factor
 * @param b - Second factor
 * @returns Product of a and b as BigInt
 * @throws Error if conversion or operation fails
 * @example
 * ```typescript
 * safeMul('1000000000000000000', '2') // Returns 2000000000000000000n
 * safeMul(1.5, 2) // Returns 3n
 * ```
 */
export const safeMul = (a: BigNumberish, b: BigNumberish): bigint => {
  try {
    return BigInt(a) * BigInt(b);
  } catch (_) {
    throw new Error(`Safe multiplication failed: ${a} * ${b}`);
  }
};

/**
 * Safe division for bigint values with zero division protection
 * @param a - Dividend (value to divide)
 * @param b - Divisor (value to divide by)
 * @returns Quotient of a and b as BigInt (integer division)
 * @throws Error if divisor is zero or operation fails
 * @example
 * ```typescript
 * safeDiv('2000000000000000000', '2') // Returns 1000000000000000000n
 * safeDiv('100', '3') // Returns 33n (integer division)
 * ```
 */
export const safeDiv = (a: BigNumberish, b: BigNumberish): bigint => {
  try {
    const divisor = BigInt(b);
    if (divisor === BigInt(0)) {
      throw new Error("Division by zero");
    }
    return BigInt(a) / divisor;
  } catch (_) {
    throw new Error(`Safe division failed: ${a} / ${b}`);
  }
};

/**
 * Safe modulo operation for bigint values with zero divisor protection
 * @param a - Dividend (value to take modulo of)
 * @param b - Divisor (modulo base)
 * @returns Remainder of a divided by b as BigInt
 * @throws Error if divisor is zero or operation fails
 * @example
 * ```typescript
 * safeMod('7', '3') // Returns 1n
 * safeMod('1000000000000000000', '3') // Returns 1n
 * ```
 */
export const safeMod = (a: BigNumberish, b: BigNumberish): bigint => {
  try {
    const divisor = BigInt(b);
    if (divisor === BigInt(0)) {
      throw new Error("Modulo by zero");
    }
    return BigInt(a) % divisor;
  } catch (_) {
    throw new Error(`Safe modulo failed: ${a} % ${b}`);
  }
};

/**
 * Check if first value is greater than second
 * @param a - First value to compare
 * @param b - Second value to compare
 * @returns True if a > b, false otherwise
 * @example
 * ```typescript
 * isGreaterThan('2000000000000000000', '1000000000000000000') // Returns true
 * isGreaterThan('100', '200') // Returns false
 * ```
 */
export const isGreaterThan = (a: BigNumberish, b: BigNumberish): boolean => {
  return BigInt(a) > BigInt(b);
};

/**
 * Check if first value is greater than or equal to second
 * @param a - First value to compare
 * @param b - Second value to compare
 * @returns True if a >= b, false otherwise
 * @example
 * ```typescript
 * isGreaterThanOrEqual('1000000000000000000', '1000000000000000000') // Returns true
 * isGreaterThanOrEqual('2000000000000000000', '1000000000000000000') // Returns true
 * ```
 */
export const isGreaterThanOrEqual = (
  a: BigNumberish,
  b: BigNumberish,
): boolean => {
  return BigInt(a) >= BigInt(b);
};

/**
 * Check if first value is less than second
 * @param a - First value to compare
 * @param b - Second value to compare
 * @returns True if a < b, false otherwise
 * @example
 * ```typescript
 * isLessThan('1000000000000000000', '2000000000000000000') // Returns true
 * isLessThan('200', '100') // Returns false
 * ```
 */
export const isLessThan = (a: BigNumberish, b: BigNumberish): boolean => {
  return BigInt(a) < BigInt(b);
};

/**
 * Check if first value is less than or equal to second
 * @param a - First value to compare
 * @param b - Second value to compare
 * @returns True if a <= b, false otherwise
 * @example
 * ```typescript
 * isLessThanOrEqual('1000000000000000000', '1000000000000000000') // Returns true
 * isLessThanOrEqual('1000000000000000000', '2000000000000000000') // Returns true
 * ```
 */
export const isLessThanOrEqual = (
  a: BigNumberish,
  b: BigNumberish,
): boolean => {
  return BigInt(a) <= BigInt(b);
};

/**
 * Check if two values are equal
 * @param a - First value to compare
 * @param b - Second value to compare
 * @returns True if a === b, false otherwise
 * @example
 * ```typescript
 * isEqual('1000000000000000000', '1000000000000000000') // Returns true
 * isEqual('100', '200') // Returns false
 * ```
 */
export const isEqual = (a: BigNumberish, b: BigNumberish): boolean => {
  return BigInt(a) === BigInt(b);
};

/**
 * Get minimum of two values
 * @param a - First value to compare
 * @param b - Second value to compare
 * @returns The smaller of the two values as BigInt
 * @example
 * ```typescript
 * min('1000000000000000000', '2000000000000000000') // Returns 1000000000000000000n
 * min('200', '100') // Returns 100n
 * ```
 */
export const min = (a: BigNumberish, b: BigNumberish): bigint => {
  return BigInt(a) < BigInt(b) ? BigInt(a) : BigInt(b);
};

/**
 * Get maximum of two values
 * @param a - First value to compare
 * @param b - Second value to compare
 * @returns The larger of the two values as BigInt
 * @example
 * ```typescript
 * max('1000000000000000000', '2000000000000000000') // Returns 2000000000000000000n
 * max('100', '200') // Returns 200n
 * ```
 */
export const max = (a: BigNumberish, b: BigNumberish): bigint => {
  return BigInt(a) > BigInt(b) ? BigInt(a) : BigInt(b);
};

/**
 * Convert BigInt value to string representation
 * @param value - Value to convert to string
 * @returns String representation of the BigInt value
 * @example
 * ```typescript
 * toString('1000000000000000000') // Returns '1000000000000000000'
 * toString(123n) // Returns '123'
 * ```
 */
export const toString = (value: BigNumberish): string => {
  return BigInt(value).toString();
};

/**
 * Convert BigInt value to hexadecimal string with 0x prefix
 * @param value - Value to convert to hex
 * @returns Hexadecimal string with 0x prefix
 * @example
 * ```typescript
 * toHex('255') // Returns '0xff'
 * toHex(1000000000000000000n) // Returns '0xde0b6b3a7640000'
 * ```
 */
export const toHex = (value: BigNumberish): `0x${string}` => {
  return `0x${BigInt(value).toString(16)}` as `0x${string}`;
};

/**
 * Check if value is zero
 * @param value - Value to check
 * @returns True if value equals zero, false otherwise
 * @example
 * ```typescript
 * isZero('0') // Returns true
 * isZero('1000000000000000000') // Returns false
 * isZero(0n) // Returns true
 * ```
 */
export const isZero = (value: BigNumberish): boolean => {
  return BigInt(value) === BigInt(0);
};

/**
 * Check if value is positive (greater than zero)
 * @param value - Value to check
 * @returns True if value is positive, false otherwise
 * @example
 * ```typescript
 * isPositive('1000000000000000000') // Returns true
 * isPositive('0') // Returns false
 * isPositive('-100') // Returns false
 * ```
 */
export const isPositive = (value: BigNumberish): boolean => {
  return BigInt(value) > BigInt(0);
};

/**
 * Check if value is negative (less than zero)
 * @param value - Value to check
 * @returns True if value is negative, false otherwise
 * @example
 * ```typescript
 * isNegative('-1000000000000000000') // Returns true
 * isNegative('0') // Returns false
 * isNegative('100') // Returns false
 * ```
 */
export const isNegative = (value: BigNumberish): boolean => {
  return BigInt(value) < BigInt(0);
};

/**
 * Truncate decimal places from a formatted number string
 * @param value - String representation of the number to truncate
 * @param decimals - Number of decimal places to keep
 * @returns String with truncated decimal places
 * @example
 * ```typescript
 * truncateDecimals('1.23456789', 2) // Returns '1.23'
 * truncateDecimals('100.999', 0) // Returns '100'
 * truncateDecimals('0.001234', 4) // Returns '0.0012'
 * ```
 */
export const truncateDecimals = (value: string, decimals: number): string => {
  if (decimals < 0) {
    throw new Error("Decimals must be non-negative");
  }

  const [integerPart, decimalPart = ""] = value.split(".");

  if (decimals === 0) {
    return integerPart;
  }

  const truncatedDecimal = decimalPart.slice(0, decimals) || "00";
  return `${integerPart}.${truncatedDecimal}`;
};

/**
 * Truncate decimal places from a BigInt value with specified decimals
 * @param value - BigInt value to truncate
 * @param fromDecimals - Current decimal places of the value
 * @param toDecimals - Target decimal places to truncate to
 * @returns String with truncated decimal places
 * @example
 * ```typescript
 * truncateFromUnits(1234567n, 6, 2) // Returns '1.23' (USDC: 6->2 decimals)
 * truncateFromUnits(1000000000000000000n, 18, 4) // Returns '1.0000' (ETH: 18->4 decimals)
 * ```
 */
export const truncateFromUnits = (
  value: BigNumberish,
  fromDecimals: number,
  toDecimals: number,
): string => {
  if (toDecimals > fromDecimals) {
    throw new Error("Target decimals cannot be greater than source decimals");
  }

  if (toDecimals < 0 || fromDecimals < 0) {
    throw new Error("Decimals must be non-negative");
  }

  const formatted = formatUnitsSafe(value, fromDecimals);
  return truncateDecimals(formatted, toDecimals);
};
