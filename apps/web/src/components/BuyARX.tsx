"use client";
import {
  useAccount,
  useChainId,
  usePublicClient,
  useWalletClient,
  useSwitchChain,
  useBalance,
} from "wagmi";
import { useEffect, useMemo, useState } from "react";
import { Button } from "@arx/ui";
import { encodePacked, hashMessage, keccak256, parseUnits, toHex } from "viem";
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
  const [deadlineMinutes, setDeadlineMinutes] = useState(
    constants.defaultDeadlineMinutes,
  );
  const [amountIn, setAmountIn] = useState<string>("");
  const [quoteUsdcOut, setQuoteUsdcOut] = useState<bigint | null>(null);
  const [payToken, setPayToken] = useState<"ETH" | "USDC">("USDC");
  const [payOpen, setPayOpen] = useState(false);
  const [salePrice, setSalePrice] = useState<bigint | null>(null);
  const [slippagePct, setSlippagePct] = useState<number>(1);
  const [slipOpen, setSlipOpen] = useState(false);
  const [slipMode, setSlipMode] = useState<"pct" | "bps">("pct");
  const [usdcAllowance, setUsdcAllowance] = useState<bigint | null>(null);
  const [hasPermit, setHasPermit] = useState<boolean>(true);
  const [showAdvanced, setShowAdvanced] = useState(false);
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

  // Fetch on-chain ARX price from sale
  async function refreshPrice() {
    if (!publicClient) return;
    const sale = cfg.ARX_TOKEN_SALE as `0x${string}` | undefined;
    if (!sale) return;
    try {
      const p = await publicClient.readContract({
        address: sale,
        abi: ARX_TOKEN_SALE_ABI,
        functionName: "priceUSDC",
        args: [],
        chainId: targetChainId,
      });
      setSalePrice(p as bigint);
    } catch {}
  }

  // Initial price load
  useMemo(() => {
    refreshPrice();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [publicClient, cfg.ARX_TOKEN_SALE, targetChainId]);

  // Preload USDC allowance and detect permit support
  useEffect(() => {
    let active = true;
    async function load() {
      try {
        const sale = cfg.ARX_TOKEN_SALE as `0x${string}` | undefined;
        const usdc = cfg.USDC as `0x${string}` | undefined;
        if (!publicClient || !address || !sale || !usdc) return;
        const alw = (await publicClient.readContract({
          address: usdc,
          abi: ERC20_ABI,
          functionName: "allowance",
          args: [address, sale],
          chainId: targetChainId,
        })) as bigint;
        if (active) setUsdcAllowance(alw);
        // detect permit support via nonces
        try {
          await publicClient.readContract({
            address: usdc,
            abi: ERC20_ABI,
            functionName: "nonces",
            args: [address],
            chainId: targetChainId,
          });
          if (active) setHasPermit(true);
        } catch {
          if (active) setHasPermit(false);
        }
      } catch {}
    }
    load();
    const id = setInterval(load, 20000);
    return () => {
      active = false;
      clearInterval(id);
    };
  }, [address, cfg.USDC, cfg.ARX_TOKEN_SALE, targetChainId, publicClient]);

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
      if (!sale || !usdc || !address) return;
      const amountUsdc = BigInt(
        Math.floor(Number(amountIn || 0) * 1e6).toString(),
      );
      // Try permit first; fallback to approve if signature fails
      try {
        const nonce = (await publicClient.readContract({
          address: usdc,
          abi: ERC20_ABI,
          functionName: "nonces",
          args: [address],
          chainId: targetChainId,
        })) as bigint;
        const name = (await publicClient.readContract({
          address: usdc,
          abi: ERC20_ABI,
          functionName: "name",
          args: [],
          chainId: targetChainId,
        })) as string;
        const version = "1"; // common for USDC
        const permitDeadline = deadline;

        // EIP-2612 typed data
        const domain = {
          name,
          version,
          chainId: targetChainId,
          verifyingContract: usdc,
        } as const;
        const types = {
          Permit: [
            { name: "owner", type: "address" },
            { name: "spender", type: "address" },
            { name: "value", type: "uint256" },
            { name: "nonce", type: "uint256" },
            { name: "deadline", type: "uint256" },
          ],
        } as const;
        const values = {
          owner: address,
          spender: sale,
          value: amountUsdc,
          nonce,
          deadline: permitDeadline,
        } as const;
        const sig = await wallet.signTypedData({
          domain,
          types,
          primaryType: "Permit",
          message: values,
        });
        // split signature
        const r = `0x${sig.slice(2, 66)}` as `0x${string}`;
        const s = `0x${sig.slice(66, 130)}` as `0x${string}`;
        const v = Number(`0x${sig.slice(130, 132)}`);

        // Call buyWithUSDC after submitting permit directly via token or let sale spend after approve+buy
        // Since sale expects allowance on itself, we need to submit permit to token contract first
        await wallet.writeContract({
          address: usdc,
          abi: ERC20_ABI,
          functionName: "permit",
          args: [address, sale, amountUsdc, permitDeadline, v, r, s],
          chainId: targetChainId,
        });
      } catch {
        // fallback approve
        await wallet.writeContract({
          address: usdc,
          abi: ERC20_ABI,
          functionName: "approve",
          args: [sale!, amountUsdc],
          chainId: targetChainId,
        });
      }
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
    // Apply slippage protection to USDC out using percent or bps
    const quoted = quoteUsdcOut ?? BigInt(0);
    const effectiveBps = (() => {
      const pct = slipMode === "pct" ? slippagePct : slippagePct / 100;
      const bps = Math.round(Math.max(0, Math.min(100, pct)) * 100);
      return Math.max(0, Math.min(10000, bps));
    })();
    const minOut =
      quoted === BigInt(0)
        ? BigInt(0)
        : (quoted * BigInt(10000 - effectiveBps)) / BigInt(10000);
    await wallet.writeContract({
      address: zap,
      abi: ARX_ZAP_ROUTER_ABI,
      functionName: "zapETHAndBuy",
      args: [pathFromWETH, minOut, address!, deadline],
      value,
      chainId: targetChainId,
    });
  }
  return (
    <div className="mx-auto w-full max-w-3xl">
      <div className="surface-card p-6 md:p-8 brand-glow">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-2xl md:text-3xl font-semibold tracking-tight">
              Buy <span className="text-[var(--brand-primary)]">ARX</span>
            </h1>
            <p className="mt-1 text-sm text-neutral-400">
              Swap ETH or spend USDC to mint ARX 1:1 (6 decimals)
            </p>
          </div>
        </div>

        {!isConnected ? (
          <p className="mt-6 text-sm text-neutral-400">
            Connect a wallet to continue.
          </p>
        ) : (
          <div className="mt-6 space-y-5">
            <div className="text-xs text-neutral-400 break-all">
              Wallet: {address}
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2 relative">
                <label className="text-sm">Pay with</label>
                <button
                  type="button"
                  className="w-full input-dark flex items-center justify-between px-3 py-2"
                  onClick={() => setPayOpen((v) => !v)}
                >
                  <span className="flex items-center gap-2">
                    <img
                      src={
                        payToken === "ETH"
                          ? "/tokens/eth.svg"
                          : "/tokens/usdc.svg"
                      }
                      width={18}
                      height={18}
                      alt={payToken}
                    />
                    <span className="font-medium">{payToken}</span>
                    <span className="text-xs text-neutral-500">
                      {payToken === "ETH"
                        ? `${ethBal ? (Number(ethBal.value) / 1e18).toFixed(4) : 0} ETH`
                        : `${usdcBal ? (Number(usdcBal.value) / 1e6).toFixed(2) : 0} USDC`}
                    </span>
                  </span>
                  <span className="text-neutral-500">▾</span>
                </button>
                {payOpen && (
                  <div className="absolute z-10 mt-1 w-full rounded-md border border-white/10 bg-black/60 backdrop-blur p-1">
                    <button
                      className="w-full flex items-center justify-between gap-2 px-3 py-2 rounded hover:bg-white/10"
                      onClick={() => {
                        setPayToken("ETH");
                        setPayOpen(false);
                      }}
                    >
                      <span className="flex items-center gap-2">
                        <img
                          src="/tokens/eth.svg"
                          width={18}
                          height={18}
                          alt="ETH"
                        />
                        <span>ETH</span>
                      </span>
                      <span className="text-xs text-neutral-500">
                        {ethBal ? (Number(ethBal.value) / 1e18).toFixed(4) : 0}
                      </span>
                    </button>
                    <button
                      className="w-full flex items-center justify-between gap-2 px-3 py-2 rounded hover:bg-white/10"
                      onClick={() => {
                        setPayToken("USDC");
                        setPayOpen(false);
                      }}
                    >
                      <span className="flex items-center gap-2">
                        <img
                          src="/tokens/usdc.svg"
                          width={18}
                          height={18}
                          alt="USDC"
                        />
                        <span>USDC</span>
                      </span>
                      <span className="text-xs text-neutral-500">
                        {usdcBal ? (Number(usdcBal.value) / 1e6).toFixed(2) : 0}
                      </span>
                    </button>
                  </div>
                )}
              </div>

              <div className="space-y-2">
                <label className="text-sm">Amount In ({payToken})</label>
                <input
                  className="w-full input-dark"
                  type="number"
                  placeholder={`Enter ${payToken} amount`}
                  min="0"
                  step="any"
                  value={amountIn}
                  onChange={(e) => setAmountIn(e.target.value)}
                />
                <div className="text-xs text-neutral-500">
                  Use a positive amount; max two decimals for USDC.
                </div>
              </div>

              <div className="space-y-2"></div>
            </div>

            <div className="mt-2">
              <button
                type="button"
                className="text-xs text-neutral-400 hover:text-neutral-200"
                onClick={() => setShowAdvanced((v) => !v)}
              >
                {showAdvanced ? "Hide" : "Show"} Advanced
              </button>
              {showAdvanced && (
                <div className="mt-3 grid gap-4 md:grid-cols-2">
                  <div className="space-y-2 relative">
                    <label className="text-sm">Slippage</label>
                    <button
                      type="button"
                      className="input-dark w-28 px-3 py-2 flex items-center justify-between"
                      onClick={() => setSlipOpen((v) => !v)}
                    >
                      <span className="text-sm">
                        {slipMode === "pct"
                          ? `${slippagePct.toFixed(1)}%`
                          : `${Math.round(slippagePct)} bps`}
                      </span>
                      <span className="text-neutral-500">▾</span>
                    </button>
                    {slipOpen && (
                      <div className="absolute z-10 mt-1 w-60 rounded-md border border-white/10 bg-black/60 backdrop-blur p-3 space-y-2">
                        <div className="flex items-center gap-2">
                          <button
                            className={`px-2 py-1 rounded text-xs ${slipMode === "pct" ? "bg-white/10" : ""}`}
                            onClick={() => setSlipMode("pct")}
                          >
                            % mode
                          </button>
                          <button
                            className={`px-2 py-1 rounded text-xs ${slipMode === "bps" ? "bg-white/10" : ""}`}
                            onClick={() => setSlipMode("bps")}
                          >
                            bps mode
                          </button>
                        </div>
                        {slipMode === "pct" ? (
                          <input
                            className="w-full input-dark"
                            type="number"
                            min="0"
                            max="100"
                            step="0.1"
                            placeholder="1.0"
                            value={slippagePct}
                            onChange={(e) =>
                              setSlippagePct(Number(e.target.value))
                            }
                          />
                        ) : (
                          <input
                            className="w-full input-dark"
                            type="number"
                            min="0"
                            max="10000"
                            step="1"
                            placeholder="100"
                            value={slippagePct}
                            onChange={(e) =>
                              setSlippagePct(Number(e.target.value))
                            }
                          />
                        )}
                        <div className="text-xs text-neutral-500">
                          Protects min USDC out when zapping.
                        </div>
                      </div>
                    )}
                  </div>
                  <div className="space-y-2">
                    <label className="text-sm">Deadline (minutes)</label>
                    <input
                      className="w-full input-dark"
                      type="number"
                      value={deadlineMinutes}
                      onChange={(e) =>
                        setDeadlineMinutes(Number(e.target.value))
                      }
                    />
                  </div>
                </div>
              )}
            </div>

            {(quoteUsdcOut != null || salePrice != null) && (
              <div className="flex items-baseline gap-4">
                {salePrice != null && (
                  <div className="text-2xl font-semibold tracking-tight">
                    <span className="text-neutral-400 text-sm mr-2">Price</span>
                    <span className="text-[var(--brand-primary)]">
                      {Number(salePrice) / 1e6} USDC
                    </span>
                    <span className="text-neutral-400 text-sm ml-1">/ ARX</span>
                  </div>
                )}
                {quoteUsdcOut != null && (
                  <div className="text-sm text-neutral-300">
                    Quote USDC out:{" "}
                    <span className="text-[var(--brand-primary)]">
                      {Number(quoteUsdcOut) / 1e6}
                    </span>
                  </div>
                )}
              </div>
            )}

            <div className="flex gap-3">
              <Button
                onClick={onQuote}
                disabled={!amountIn || Number(amountIn) <= 0}
              >
                Quote
              </Button>
              <Button
                onClick={onBuy}
                disabled={!amountIn || Number(amountIn) <= 0}
                className="bg-[var(--brand-primary)] text-black font-semibold px-8 py-3 rounded-md shadow-[0_10px_30px_-10px_rgba(120,88,255,0.6)] hover:shadow-[0_12px_36px_-10px_rgba(120,88,255,0.8)] transition-shadow"
              >
                {(() => {
                  if (payToken !== "USDC") return "Buy";
                  const needed = (() => {
                    const n = Number(amountIn || 0);
                    if (!isFinite(n) || n <= 0) return 0n;
                    return BigInt(Math.floor(n * 1e6).toString());
                  })();
                  const hasAlw =
                    usdcAllowance != null && usdcAllowance >= needed;
                  const canPermit = hasPermit;
                  return !hasAlw && !canPermit ? "Approve" : "Buy";
                })()}
              </Button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
