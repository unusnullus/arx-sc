// Placeholder ABIs; wire actual ABIs via codegen later
export const ARX_ABI = [
  {
    type: "function",
    name: "mint",
    stateMutability: "nonpayable",
    inputs: [
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [],
  },
];

export const ARX_TOKEN_SALE_ABI = [
  {
    type: "function",
    name: "buyWithUSDC",
    stateMutability: "nonpayable",
    inputs: [{ name: "usdcAmount", type: "uint256" }],
    outputs: [],
  },
  {
    type: "function",
    name: "buyFor",
    stateMutability: "nonpayable",
    inputs: [
      { name: "buyer", type: "address" },
      { name: "usdcAmount", type: "uint256" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "priceUSDC",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
];

export const ARX_ZAP_ROUTER_ABI = [
  {
    type: "function",
    name: "zapERC20AndBuy",
    stateMutability: "nonpayable",
    inputs: [
      { name: "tokenIn", type: "address" },
      { name: "amountIn", type: "uint256" },
      { name: "path", type: "bytes" },
      { name: "minUsdcOut", type: "uint256" },
      { name: "buyer", type: "address" },
      { name: "deadline", type: "uint256" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "zapETHAndBuy",
    stateMutability: "payable",
    inputs: [
      { name: "pathFromWETH", type: "bytes" },
      { name: "minUsdcOut", type: "uint256" },
      { name: "buyer", type: "address" },
      { name: "deadline", type: "uint256" },
    ],
    outputs: [],
  },
];

export const ERC20_ABI = [
  {
    type: "function",
    name: "approve",
    stateMutability: "nonpayable",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
  },
];

export const UNISWAP_QUOTER_V2_ABI = [
  {
    type: "function",
    name: "quoteExactInput",
    stateMutability: "view",
    inputs: [
      { name: "path", type: "bytes" },
      { name: "amountIn", type: "uint256" },
    ],
    // returns (uint256 amountOut, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate)
    outputs: [
      { name: "amountOut", type: "uint256" },
      { name: "sqrtPriceX96After", type: "uint160" },
      { name: "initializedTicksCrossed", type: "uint32" },
      { name: "gasEstimate", type: "uint256" },
    ],
  },
];
