import { cn } from "@arx/ui/lib";
import { forwardRef } from "react";

interface MapItemProps {
  date: string;
  title: string;
  description: string;
  isActive?: boolean;
  isPassed?: boolean;
  progress?: number;
  isLast?: boolean;
}

export const MapItem = forwardRef<HTMLDivElement, MapItemProps>(
  (
    {
      date,
      title,
      description,
      isActive = false,
      isPassed = false,
      progress = 0,
      isLast = false,
    },
    ref,
  ) => {
    const isCompleted = isPassed || isActive;

    return (
      <div
        ref={ref}
        className={cn("flex gap-10 transition-opacity duration-300 md:gap-22", {
          "opacity-70": !isCompleted,
        })}
      >
        <div className="relative flex w-0.5 flex-col items-center">
          <div
            className={cn(
              "box-content min-h-4 w-4 rounded-full border-12 border-transparent transition-all duration-500",
              {
                "border-tertiary-10": isActive,
              },
            )}
          >
            <div
              className={`box-content min-h-4 w-4 rounded-full transition-all duration-300 ${
                isCompleted
                  ? isActive
                    ? "bg-secondary scale-110"
                    : "bg-secondary"
                  : "bg-content-50"
              }`}
            />
          </div>
          {!isLast && (
            <div className="relative h-full w-0.5 overflow-hidden">
              <div className="border-content-50 absolute inset-0 w-0 border-r-[2px] border-dashed" />
              <div
                className="bg-secondary absolute top-0 right-0 left-0 transition-all duration-500 ease-in-out"
                style={{
                  height: isCompleted ? `${Math.min(100, progress)}%` : "0%",
                  opacity: isCompleted ? 1 : 0,
                }}
              />
            </div>
          )}
        </div>
        <div className="flex flex-col gap-6 pt-2 pb-25 md:gap-8 md:pb-30">
          <span className="text-content-70 font-geist-mono text-base md:text-lg">
            {date}
          </span>
          <div className="flex flex-col gap-3">
            <h5 className="text-content-100 text-2xl font-semibold transition-colors duration-300 md:text-4xl">
              {title}
            </h5>
            <p className="text-content-70 text-base md:text-lg">
              {description}
            </p>
          </div>
        </div>
      </div>
    );
  },
);

MapItem.displayName = "MapItem";
