import { LiquidityStep } from "../types";

interface LiquidityStepsProps {
  steps: LiquidityStep[];
}

export const LiquiditySteps = ({ steps }: LiquidityStepsProps) => {
  return (
    <div className="bg-input flex flex-col gap-3 rounded-2xl p-0">
      <h3 className="text-content-100 text-sm font-semibold">Steps</h3>
      <div className="space-y-3">
        {steps.map((step, index) => (
          <div
            key={step.id}
            className={`flex items-center gap-3 rounded-xl p-3 transition-colors ${
              step.status === "active"
                ? "bg-primary/10 border-primary/20 border"
                : step.status === "completed"
                  ? "border border-green-200 bg-green-50 text-green-500"
                  : step.status === "processing"
                    ? "border border-yellow-200 bg-yellow-50"
                    : "bg-white-10"
            }`}
          >
            <div
              className={`flex h-6 w-6 items-center justify-center rounded-full text-xs font-semibold ${
                step.status === "active"
                  ? "bg-primary text-primary-foreground"
                  : step.status === "completed"
                    ? "bg-green-500 text-white"
                    : step.status === "processing"
                      ? "animate-pulse bg-yellow-500 text-white"
                      : "bg-content-50 text-content-100"
              }`}
            >
              {step.status === "completed" ? "✓" : index + 1}
            </div>
            <div className="flex-1">
              <div className="text-sm font-medium">{step.title}</div>
              {step.description && (
                <div className="text-xs">{step.description}</div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
