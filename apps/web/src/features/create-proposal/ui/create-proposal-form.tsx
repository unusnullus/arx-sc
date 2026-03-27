"use client";

import { useMemo, useEffect } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useAccount, useChainId } from "wagmi";
import {
  isAddress,
  parseUnits,
  encodeFunctionData,
  parseAbi,
  formatUnits,
  type Address,
} from "viem";

import {
  Textarea,
  toast,
  Button,
  Input,
  Spinner,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Form,
  FormField,
  FormItem,
  FormLabel,
  FormControl,
  FormMessage,
} from "@arx/ui/components";

import { useCreateProposal } from "../hooks/use-create-proposal";
import { useVotingPower, useGovernorConfig } from "@/entities/governance";
import { addressesByChain, FALLBACK_CHAIN_ID } from "@arx/config";
import { cn } from "@arx/ui/lib";
import { PROXY_CONTRACTS_MAP } from "../constants";

type ActionType = "MINT" | "UPGRADE";

const formSchema = z
  .object({
    actionType: z.enum(["MINT", "UPGRADE"]),
    mintRecipient: z.string().optional(),
    mintAmount: z.string().optional(),
    upgradeProxyType: z.string().optional(),
    upgradeProxyAddress: z.string().optional(),
    upgradeNewImplementation: z.string().optional(),
    value: z.string(),
    description: z
      .string()
      .min(10, "Description must be at least 10 characters"),
  })
  .superRefine((data, ctx) => {
    if (data.actionType === "MINT") {
      if (!data.mintRecipient) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Recipient address is required",
          path: ["mintRecipient"],
        });
      } else if (!isAddress(data.mintRecipient)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Invalid address format",
          path: ["mintRecipient"],
        });
      }

      if (!data.mintAmount) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Amount is required",
          path: ["mintAmount"],
        });
      } else {
        const num = Number(data.mintAmount);
        if (isNaN(num) || num <= 0) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "Amount must be a positive number",
            path: ["mintAmount"],
          });
        } else if (!/^\d*(?:\.\d*)?$/.test(data.mintAmount)) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "Invalid number format",
            path: ["mintAmount"],
          });
        }
      }
    }

    if (data.actionType === "UPGRADE") {
      if (data.upgradeProxyType === "CUSTOM") {
        if (!data.upgradeProxyAddress) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "Proxy address is required",
            path: ["upgradeProxyAddress"],
          });
        } else if (!isAddress(data.upgradeProxyAddress)) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "Invalid address format",
            path: ["upgradeProxyAddress"],
          });
        }
      }

      if (!data.upgradeNewImplementation) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Implementation address is required",
          path: ["upgradeNewImplementation"],
        });
      } else if (!isAddress(data.upgradeNewImplementation)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Invalid address format",
          path: ["upgradeNewImplementation"],
        });
      }
    }
  });

type FormData = z.infer<typeof formSchema>;

const KNOWN_PROXIES = [
  { label: "Governor", value: "ARX_GOVERNOR" },
  { label: "Token Sale", value: "ARX_TOKEN_SALE" },
  { label: "Zap Router", value: "ARX_ZAP_ROUTER" },
  { label: "Custom", value: "CUSTOM" },
] as const;

const MINT_ABI = parseAbi(["function mint(address to, uint256 amount)"]);
const UPGRADE_ABI = parseAbi([
  "function upgradeToAndCall(address newImplementation, bytes data)",
]);

const getCalldataForForm = (
  values: FormData,
  config: Record<string, string | undefined>,
) => {
  if (values.actionType === "MINT") {
    const arxAddress = config.ARX;
    if (
      !arxAddress ||
      !values.mintRecipient ||
      !isAddress(values.mintRecipient) ||
      !values.mintAmount ||
      values.mintAmount === ""
    ) {
      return null;
    }
    try {
      const amountBigInt = parseUnits(values.mintAmount, 6);
      const calldata = encodeFunctionData({
        abi: MINT_ABI,
        functionName: "mint",
        args: [values.mintRecipient as Address, amountBigInt],
      });
      return {
        target: arxAddress,
        calldata,
        summary: `Mint ${values.mintAmount} ARX to ${values.mintRecipient.slice(0, 6)}...${values.mintRecipient.slice(-4)}`,
      };
    } catch {
      return null;
    }
  }

  if (values.actionType === "UPGRADE") {
    let proxyAddress: string | undefined;

    if (values.upgradeProxyType === "CUSTOM") {
      proxyAddress = values.upgradeProxyAddress || undefined;
    } else if (values.upgradeProxyType) {
      proxyAddress = config[values.upgradeProxyType] as string | undefined;
    }

    if (
      !proxyAddress ||
      !isAddress(proxyAddress) ||
      !values.upgradeNewImplementation ||
      values.upgradeNewImplementation === "" ||
      !isAddress(values.upgradeNewImplementation)
    ) {
      return null;
    }

    try {
      const calldata = encodeFunctionData({
        abi: UPGRADE_ABI,
        functionName: "upgradeToAndCall",
        args: [
          values.upgradeNewImplementation as Address,
          "0x" as `0x${string}`,
        ],
      });
      return {
        target: proxyAddress,
        calldata,
        summary: `Upgrade ${proxyAddress.slice(0, 6)}...${proxyAddress.slice(-4)} to ${values.upgradeNewImplementation.slice(0, 6)}...${values.upgradeNewImplementation.slice(-4)}`,
      };
    } catch {
      return null;
    }
  }

  return null;
};

export const CreateProposalForm = () => {
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const targetChainId = chainId ?? FALLBACK_CHAIN_ID;

  const cfg = useMemo(
    () => addressesByChain[targetChainId] || {},
    [targetChainId],
  );

  const { createProposal, isCreating } = useCreateProposal();
  const { governorVotes } = useVotingPower();
  const { config } = useGovernorConfig();

  const form = useForm<FormData>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      actionType: "MINT",
      mintRecipient: address || "",
      mintAmount: "",
      upgradeProxyType: "ARX_GOVERNOR",
      upgradeProxyAddress: "",
      upgradeNewImplementation: "",
      value: "0",
      description: "",
    },
    mode: "onChange",
  });

  const actionType = form.watch("actionType");
  const formValues = form.watch();

  useEffect(() => {
    if (address && !formValues.mintRecipient) {
      form.setValue("mintRecipient", address);
    }
  }, [address, formValues.mintRecipient, form]);

  useEffect(() => {
    if (actionType === "MINT") {
      form.setValue("upgradeProxyAddress", "", { shouldValidate: false });
      form.setValue("upgradeNewImplementation", "", { shouldValidate: false });
    } else if (actionType === "UPGRADE") {
      form.setValue("mintAmount", "", { shouldValidate: false });
      const currentProxyType = form.getValues("upgradeProxyType");
      if (!currentProxyType || currentProxyType === "") {
        form.setValue("upgradeProxyType", "ARX_GOVERNOR", {
          shouldValidate: false,
        });
      }
    }
  }, [actionType, form]);

  const previewData = useMemo(
    () => getCalldataForForm(formValues, cfg),
    [formValues, cfg],
  );

  const hasEnoughVotes = useMemo(() => {
    if (!config || !governorVotes) return false;
    return governorVotes >= config.proposalThreshold;
  }, [config, governorVotes]);

  const votesNeeded = useMemo(() => {
    if (!config || !governorVotes) return BigInt(0);
    if (governorVotes >= config.proposalThreshold) return BigInt(0);
    return config.proposalThreshold - governorVotes;
  }, [config, governorVotes]);

  const onSubmit = async (data: FormData) => {
    if (!isConnected || !address) {
      toast.error("Please connect your wallet");
      return;
    }

    const executionData = getCalldataForForm(data, cfg);

    if (!executionData) {
      toast.error("Invalid form data. Please check all fields.");
      return;
    }

    try {
      const valueBigInt = data.value ? parseUnits(data.value, 18) : BigInt(0);

      await createProposal({
        targets: [executionData.target as Address],
        values: [valueBigInt],
        calldatas: [executionData.calldata as `0x${string}`],
        description: data.description.trim(),
      });

      form.reset({
        actionType: "MINT",
        mintRecipient: address || "",
        mintAmount: "",
        upgradeProxyType: "ARX_GOVERNOR",
        upgradeProxyAddress: "",
        upgradeNewImplementation: "",
        value: "0",
        description: "",
      });
    } catch (error) {
      console.error("Failed to create proposal:", error);
      toast.error("Failed to create proposal");
    }
  };

  const isDisabled =
    !isConnected ||
    !previewData ||
    !formValues.description ||
    !hasEnoughVotes ||
    isCreating ||
    !form.formState.isValid;

  if (!isConnected) {
    return (
      <div className="text-content-50 border-white-10 rounded-lg border p-6 text-center">
        Please connect your wallet to create a proposal
      </div>
    );
  }

  return (
    <Form {...form}>
      <form
        onSubmit={form.handleSubmit(onSubmit)}
        className="flex flex-col gap-6"
      >
        {!hasEnoughVotes && (
          <div className="border-white-10 bg-white-5 rounded-lg border p-4">
            <p className="text-content-100 text-sm font-medium">
              Insufficient voting power
            </p>
            <p className="text-content-70 mt-1 text-sm">
              You need {formatUnits(votesNeeded, 6)} more ARX to create a
              proposal.
              {config && (
                <>
                  {" "}
                  Current threshold: {formatUnits(
                    config.proposalThreshold,
                    6,
                  )}{" "}
                  ARX
                </>
              )}
            </p>
          </div>
        )}

        <FormField
          control={form.control}
          name="actionType"
          render={({ field }) => (
            <FormItem>
              <FormLabel className="text-content-70">Action Type</FormLabel>
              <Select
                value={field.value || "MINT"}
                onValueChange={(val) => {
                  if (val && (val === "MINT" || val === "UPGRADE")) {
                    field.onChange(val as ActionType);
                    if (val === "MINT") {
                      form.setValue("upgradeProxyAddress", "");
                      form.setValue("upgradeNewImplementation", "");
                    } else {
                      form.setValue("mintAmount", "");
                    }
                  }
                }}
                disabled={isCreating}
              >
                <FormControl>
                  <SelectTrigger className="text-content-100 border-white-10 bg-content-black w-full rounded-lg border px-4">
                    <SelectValue placeholder="Select action type">
                      <span>
                        {field.value === "MINT"
                          ? "Mint Tokens"
                          : "Upgrade Contract"}
                      </span>
                    </SelectValue>
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value="MINT">Mint Tokens</SelectItem>
                  <SelectItem value="UPGRADE">Upgrade Contract</SelectItem>
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )}
        />

        {actionType === "MINT" && (
          <>
            <FormField
              control={form.control}
              name="mintRecipient"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-content-70">Recipient</FormLabel>
                  <FormControl>
                    <Input
                      {...field}
                      placeholder="0x..."
                      disabled={isCreating}
                      className={cn(
                        "text-content-100 border-white-10 bg-content-black rounded-lg border px-4",
                        {
                          "cursor-not-allowed opacity-50": isCreating,
                        },
                      )}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="mintAmount"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-content-70">
                    Amount (ARX)
                  </FormLabel>
                  <FormControl>
                    <Input
                      {...field}
                      placeholder="0"
                      disabled={isCreating}
                      className={cn(
                        "text-content-100 border-white-10 bg-content-black rounded-lg border px-4",
                        {
                          "cursor-not-allowed opacity-50": isCreating,
                        },
                      )}
                    />
                  </FormControl>
                  <FormMessage />
                  <p className="text-content-50 text-xs">
                    Amount of ARX tokens to mint (6 decimals)
                  </p>
                </FormItem>
              )}
            />
          </>
        )}

        {actionType === "UPGRADE" && (
          <>
            <FormField
              control={form.control}
              name="upgradeProxyType"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-content-70">
                    Proxy Contract
                  </FormLabel>
                  <Select
                    value={field.value}
                    onValueChange={(val) => {
                      field.onChange(val);
                      if (val !== "CUSTOM") {
                        form.setValue("upgradeProxyAddress", "");
                      }
                    }}
                    disabled={isCreating}
                  >
                    <FormControl>
                      <SelectTrigger className="text-content-100 border-white-10 bg-content-black w-full rounded-lg border px-4">
                        <SelectValue>
                          <span>
                            {
                              PROXY_CONTRACTS_MAP[
                                field.value as keyof typeof PROXY_CONTRACTS_MAP
                              ]
                            }
                          </span>
                        </SelectValue>
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      {KNOWN_PROXIES.map((p) => (
                        <SelectItem key={p.value} value={p.value}>
                          {p.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />

            {formValues.upgradeProxyType === "CUSTOM" &&
              formValues.upgradeProxyType && (
                <FormField
                  control={form.control}
                  name="upgradeProxyAddress"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-content-70">
                        Proxy Address
                      </FormLabel>
                      <FormControl>
                        <Input
                          {...field}
                          placeholder="0x..."
                          disabled={isCreating}
                          className={cn(
                            "text-content-100 border-white-10 bg-content-black rounded-lg border px-4",
                            {
                              "cursor-not-allowed opacity-50": isCreating,
                            },
                          )}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              )}

            <FormField
              control={form.control}
              name="upgradeNewImplementation"
              render={({ field }) => (
                <FormItem>
                  <FormLabel className="text-content-70">
                    New Implementation Address
                  </FormLabel>
                  <FormControl>
                    <Input
                      {...field}
                      placeholder="0x..."
                      disabled={isCreating}
                      className={cn(
                        "text-content-100 border-white-10 bg-content-black rounded-lg border px-4",
                        {
                          "cursor-not-allowed opacity-50": isCreating,
                        },
                      )}
                    />
                  </FormControl>
                  <FormMessage />
                  <p className="text-content-50 text-xs">
                    Address of the new implementation contract
                  </p>
                </FormItem>
              )}
            />
          </>
        )}

        {previewData && (
          <div className="border-white-10 bg-white-5 rounded-lg border p-4 text-sm">
            <p className="text-content-100 mb-2 font-bold">
              Preview: {previewData.summary}
            </p>
            <div className="text-content-50 font-mono text-xs break-all">
              <p>Target: {previewData.target}</p>
              <p className="mt-1">
                Data: {previewData.calldata?.slice(0, 50) || ""}...
              </p>
            </div>
          </div>
        )}

        <FormField
          control={form.control}
          name="description"
          render={({ field }) => (
            <FormItem>
              <FormLabel className="text-content-70">Description</FormLabel>
              <FormControl>
                <Textarea
                  {...field}
                  className="border-white-10 bg-content-black text-content-100 min-h-[120px] rounded-lg border px-4 py-3"
                  placeholder="Describe proposal..."
                  disabled={isCreating}
                />
              </FormControl>
              <FormMessage />
              <p className="text-content-50 text-xs">
                Markdown is supported. This will be hashed and stored on-chain.
              </p>
            </FormItem>
          )}
        />

        <Button
          type="submit"
          disabled={isDisabled}
          className="text-content-100 bg-white-10 hover:bg-white-15 h-12 w-full rounded-[100px] py-3 text-base font-semibold"
        >
          {isCreating ? (
            <div className="flex items-center gap-2">
              Creating Proposal
              <Spinner variant="ellipsis" size={16} />
            </div>
          ) : !hasEnoughVotes ? (
            `Need ${formatUnits(votesNeeded, 6)} more ARX`
          ) : (
            "Submit Proposal"
          )}
        </Button>
      </form>
    </Form>
  );
};
