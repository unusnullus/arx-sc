# ARX Token Sale Monorepo

Production-grade monorepo for ARX token, token sale, zap router and web app.

## Overview

- Smart contracts (Foundry):
  - `ARX` — ERC20 + Permit + Burnable + AccessControl (MINTER_ROLE)
  - `ArxTokenSale` — accepts USDC, forwards 100% to silo, mints ARX at USDC price
  - `ArxZapRouter` — swaps any ERC20/ETH to USDC via Uniswap V3, then `buyFor()`
- Web app (Next.js):
  - Landing with parallax roadmap
  - `/buy` flow (wallet connect; quote via Uniswap Quoter; approvals/zap)
- Shared packages: UI, config (addresses/env), ABI
- Tooling: pnpm workspaces, Turborepo, ESLint/Prettier, Husky + lint-staged
- CI: GitHub Actions (lint + forge tests)

Price formula: `arxOut = (usdcAmount * 1e18) / priceUSDC` where `priceUSDC` uses 6 decimals.

## Repository Structure

```
apps/
  web/                 # Next.js app (Next 15, wagmi, viem, RainbowKit, Tailwind)
packages/
  contracts/           # Foundry contracts, tests, scripts
  abi/                 # Exported ABIs/types (placeholder JSON arrays)
  config/              # Addresses, constants, env-driven config
  ui/                  # Shared UI primitives (Tailwind-based)
```

## Prerequisites

- Node.js 18+ and pnpm 9+
- Foundry (forge/cast/anvil)
- GitHub CLI (optional)

## Install & Build

```bash
pnpm install --no-frozen-lockfile
pnpm -w run build
```

## Contracts

- Compile:

```bash
cd packages/contracts
forge build
```

- Test:

```bash
forge test -vv
```

### Local Deploy (Anvil)

1. Start Anvil

```bash
anvil -b 2
```

2. Deploy MockUSDC + ARX + Sale locally

```bash
cd packages/contracts
forge script script/LocalDeploy.s.sol --broadcast \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 -vv
```

Script logs will print deployed addresses for `USDC`, `ARX`, `SALE`.

## Web App - Local Run

Create `apps/web/.env.local` with local chain and addresses:

```bash
NEXT_PUBLIC_CHAIN_ID=31337
NEXT_PUBLIC_RPC_LOCAL=http://127.0.0.1:8545
NEXT_PUBLIC_ARX=<ARX_ADDRESS>
NEXT_PUBLIC_ARX_TOKEN_SALE=<SALE_ADDRESS>
NEXT_PUBLIC_USDC=<USDC_ADDRESS>
NEXT_PUBLIC_SILO_TREASURY=<YOUR_LOCAL_ADDRESS>
```

Start the web app:

```bash
pnpm -w --filter web dev
# http://localhost:3000
```

- Landing page shows hero and roadmap animation (respects reduced motion)
- `/buy` page:
  - Connect wallet
  - Local flow defaults to direct USDC -> `sale.buyWithUSDC`
  - On testnet/mainnet, you can quote via Uniswap Quoter and zap via Router

## Testnet (Sepolia/Base Sepolia) Deploy

Set env for scripts (example):

```bash
export RPC_URL=<https_rpc>
export PRIVATE_KEY=<0x...>
export USDC=<0x...>
export WETH9=<0x...>
export UNISWAP_V3_SWAPROUTER=<0x...>
export UNISWAP_V3_QUOTER=<0x...>
export SILO_TREASURY=<0x...>
export ARX_PRICE_USDC_6DP=<e.g., 5000000 for $5>
```

Deploy & wire in order:

```bash
pnpm -w --filter @arx/contracts run deploy:token
pnpm -w --filter @arx/contracts run deploy:sale
pnpm -w --filter @arx/contracts run deploy:zap
pnpm -w --filter @arx/contracts run wire:permissions
```

Populate `apps/web/.env.local` (or `.env`) with chain RPC and deployed addresses, then run `pnpm dev`.

## Packages

- `@arx/contracts`
  - `src/ARX.sol` — ERC20 + Permit + Burnable + AccessControl
  - `src/ArxTokenSale.sol` — owner setters, zapper allowlist, forward-to-silo, mint
  - `src/ArxZapRouter.sol` — Uniswap V3 exactInput to USDC, approves sale, calls `buyFor`
  - Scripts:
    - `DeployToken.s.sol`, `DeploySale.s.sol`, `DeployZap.s.sol`, `WirePermissions.s.sol`
    - `LocalDeploy.s.sol` (Anvil: MockUSDC + ARX + Sale)
- `@arx/config`
  - `addressesByChain`: per-chain addresses via env
  - `constants`: slippage, deadline defaults
- `@arx/abi`
  - Minimal ABIs for app usage (update with codegen as needed)
- `@arx/ui`
  - Tailwind-based primitives (e.g., `Button`)

## Environment Variables

Contracts & Scripts:

- `CHAIN_ID`, `RPC_URL`, `PRIVATE_KEY`, `USDC`, `WETH9`, `UNISWAP_V3_SWAPROUTER`, `UNISWAP_V3_QUOTER`, `SILO_TREASURY`, `ARX_PRICE_USDC_6DP`

Web (Next.js):

- `NEXT_PUBLIC_CHAIN_ID`, `NEXT_PUBLIC_RPC_MAINNET`, `NEXT_PUBLIC_RPC_SEPOLIA`, `NEXT_PUBLIC_RPC_BASE_SEPOLIA`, `NEXT_PUBLIC_RPC_LOCAL`
- `NEXT_PUBLIC_ARX`, `NEXT_PUBLIC_ARX_TOKEN_SALE`, `NEXT_PUBLIC_ARX_ZAP_ROUTER`
- `NEXT_PUBLIC_USDC`, `NEXT_PUBLIC_WETH9`, `NEXT_PUBLIC_UNISWAP_V3_SWAPROUTER`, `NEXT_PUBLIC_UNISWAP_V3_QUOTER`, `NEXT_PUBLIC_SILO_TREASURY`
- `NEXT_PUBLIC_WALLETCONNECT_ID`

## CI

- `.github/workflows/ci.yml` runs lint and forge tests on PRs/pushes to `main`.

## Commands (Cheat Sheet)

```bash
# Build everything
pnpm -w run build

# Contracts
cd packages/contracts
forge build && forge test -vv

# Local deploy
anvil -b 2
forge script script/LocalDeploy.s.sol --broadcast --rpc-url http://127.0.0.1:8545 --private-key <key>

# Web app
cd ../../apps/web
pnpm dev
```

## Notes

- Front-end uses `viem` + `wagmi` + `RainbowKit`.
- Reduced-motion respected for animations.
- Permit2 is an optional future enhancement.

## License

MIT
