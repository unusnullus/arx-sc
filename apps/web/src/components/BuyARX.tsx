"use client";
import {
  useAccount,
  useChainId,
  usePublicClient,
  useWalletClient,
  useSwitchChain,
  useBalance,
} from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useMemo, useState } from "react";
import { Button } from "@arx/ui";
import { encodePacked } from "viem";
import { addressesByChain, constants } from "@arx/config";
import {
  ARX_TOKEN_SALE_ABI,
  ARX_ZAP_ROUTER_ABI,
  ERC20_ABI,
  UNISWAP_QUOTER_V2_ABI,
} from "@arx/abi";

export default function BuyARX() {
  const { address, isConnected } = useAccount();
  const currentChainId = useChainId();
  const targetChainId = useMemo(
    () => Number(process.env.NEXT_PUBLIC_CHAIN_ID || 31337),
    [],
  );
  const publicClient = usePublicClient({ chainId: targetChainId });
  const { data: wallet } = useWalletClient();
  const [slippageBps, setSlippageBps] = useState(100);
  const [deadlineMinutes, setDeadlineMinutes] = useState(
    constants.defaultDeadlineMinutes,
  );
  const [amountIn, setAmountIn] = useState<string>("");
  const [quoteUsdcOut, setQuoteUsdcOut] = useState<bigint | null>(null);
  const [payToken, setPayToken] = useState<"ETH" | "USDC">("USDC");
  const cfg = useMemo(
    () => addressesByChain[targetChainId] || {},
    [targetChainId],
  );
  const { switchChain } = useSwitchChain();

  const { data: ethBal } = useBalance({
    address,
    chainId: targetChainId,
    query: { enabled: !!address },
  });
  const { data: usdcBal } = useBalance({
    address,
    token: cfg.USDC as `0x${string}` | undefined,
    chainId: targetChainId,
    query: { enabled: !!address && !!cfg.USDC },
  });

  async function ensureChain() {
    if (currentChainId !== targetChainId && switchChain) {
      try {
        await switchChain({ chainId: targetChainId });
      } catch {}
    }
  }

  async function onQuote() {
    if (payToken === "USDC") {
      const usdcAmt = BigInt(
        Math.floor(Number(amountIn || 0) * 1e6).toString(),
      );
      setQuoteUsdcOut(usdcAmt);
      return;
    }
    if (!publicClient || !cfg.UNISWAP_V3_QUOTER) return;
    const tokenIn = cfg.WETH9 as `0x${string}` | undefined;
    const tokenOut = cfg.USDC as `0x${string}` | undefined;
    if (!tokenIn || !tokenOut) {
      setPayToken("USDC");
      return;
    }
    const fee = 500;
    const path = encodePacked(
      ["address", "uint24", "address"],
      [tokenIn, fee, tokenOut],
    );
    const amount = BigInt(Math.floor(Number(amountIn || 0) * 1e18).toString());
    if (amount === BigInt(0)) return;
    const result = await publicClient.readContract({
      address: cfg.UNISWAP_V3_QUOTER,
      abi: UNISWAP_QUOTER_V2_ABI,
      functionName: "quoteExactInput",
      args: [path, amount],
      chainId: targetChainId,
    });
    const out = Array.isArray(result)
      ? (result[0] as bigint)
      : (result as unknown as { amountOut: bigint }).amountOut;
    setQuoteUsdcOut(out);
  }

  async function onBuy() {
    if (!wallet || !publicClient) return;
    await ensureChain();
    const deadline = BigInt(
      Math.floor(Date.now() / 1000) + deadlineMinutes * 60,
    );
    const sale = cfg.ARX_TOKEN_SALE as `0x${string}` | undefined;
    const zap = cfg.ARX_ZAP_ROUTER as `0x${string}` | undefined;
    const usdc = cfg.USDC as `0x${string}` | undefined;
    const weth9 = cfg.WETH9 as `0x${string}` | undefined;

    if (payToken === "USDC") {
      if (!sale || !usdc) return;
      const amountUsdc = BigInt(
        Math.floor(Number(amountIn || 0) * 1e6).toString(),
      );
      await wallet.writeContract({
        address: usdc,
        abi: ERC20_ABI,
        functionName: "approve",
        args: [sale, amountUsdc],
        chainId: targetChainId,
      });
      await wallet.writeContract({
        address: sale,
        abi: ARX_TOKEN_SALE_ABI,
        functionName: "buyWithUSDC",
        args: [amountUsdc],
        chainId: targetChainId,
      });
      return;
    }

    // ETH zap path (requires zap + WETH9 + USDC configured)
    if (!zap || !weth9 || !usdc) {
      setPayToken("USDC");
      return;
    }
    const fee = 500;
    const pathFromWETH = encodePacked(
      ["address", "uint24", "address"],
      [weth9, fee, usdc],
    );
    const value = BigInt(Math.floor(Number(amountIn || 0) * 1e18).toString());
    await wallet.writeContract({
      address: zap,
      abi: ARX_ZAP_ROUTER_ABI,
      functionName: "zapETHAndBuy",
      args: [pathFromWETH, BigInt(0), address!, deadline],
      value,
      chainId: targetChainId,
    });
  }
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-semibold">Buy $ARX</h2>
        <ConnectButton />
      </div>
      {!isConnected ? (
        <p className="text-sm text-neutral-400">
          Connect a wallet to continue.
        </p>
      ) : (
        <div className="space-y-3">
          <div className="text-xs text-neutral-400 break-all">
            Wallet: {address}
          </div>
          <div className="grid gap-3 md:grid-cols-4">
            <div>
              <label className="text-sm">Pay with</label>
              <select
                className="w-full rounded bg-neutral-900 p-2"
                value={payToken}
                onChange={(e) => setPayToken(e.target.value as "ETH" | "USDC")}
              >
                <option value="ETH">ETH</option>
                <option value="USDC">USDC</option>
              </select>
              <div className="text-xs text-neutral-500 mt-1">
                {payToken === "ETH"
                  ? `Balance: ${ethBal ? Number(ethBal.value) / 1e18 : 0} ETH`
                  : `Balance: ${usdcBal ? Number(usdcBal.value) / 1e6 : 0} USDC`}
              </div>
            </div>
            <div>
              <label className="text-sm">Amount In ({payToken})</label>
              <input
                className="w-full rounded bg-neutral-900 p-2"
                type="number"
                value={amountIn}
                onChange={(e) => setAmountIn(e.target.value)}
              />
            </div>
            <div>
              <label className="text-sm">Slippage (bps)</label>
              <input
                className="w-full rounded bg-neutral-900 p-2"
                type="number"
                value={slippageBps}
                onChange={(e) => setSlippageBps(Number(e.target.value))}
              />
            </div>
            <div>
              <label className="text-sm">Deadline (minutes)</label>
              <input
                className="w-full rounded bg-neutral-900 p-2"
                type="number"
                value={deadlineMinutes}
                onChange={(e) => setDeadlineMinutes(Number(e.target.value))}
              />
            </div>
          </div>
          {quoteUsdcOut != null && (
            <div className="text-sm text-neutral-400">
              Quote USDC out: {Number(quoteUsdcOut) / 1e6}
            </div>
          )}
          <div className="flex gap-2">
            <Button onClick={onQuote}>Quote</Button>
            <Button variant="secondary" onClick={onBuy}>
              Buy
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
