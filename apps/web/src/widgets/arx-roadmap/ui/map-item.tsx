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
      <div ref={ref} className="flex gap-22">
        <div className="w-0.5 flex flex-col items-center relative">
          <div
            className={cn(
              "box-content w-4 min-h-4 rounded-full border-12 border-transparent transition-all duration-500",
              {
                "border-tertiary-10": isActive,
              },
            )}
          >
            <div
              className={`box-content w-4 min-h-4 rounded-full transition-all duration-300 ${
                isCompleted
                  ? isActive
                    ? "bg-secondary scale-110"
                    : "bg-secondary"
                  : "bg-content-50"
              }`}
            />
          </div>
          {!isLast && (
            <div className="w-0.5 h-full relative overflow-hidden">
              <div className="absolute w-0 inset-0 border-r-[2px] border-dashed border-content-50" />
              <div
                className="absolute top-0 left-0 right-0 bg-secondary transition-all duration-500 ease-in-out"
                style={{
                  height: isCompleted ? `${Math.min(100, progress)}%` : "0%",
                  opacity: isCompleted ? 1 : 0,
                }}
              />
            </div>
          )}
        </div>
        <div className="flex flex-col gap-8 pb-30 pt-2">
          <span
            className={cn("text-content-70 text-lg font-geist-mono", {
              "text-secondary": isActive || isCompleted,
            })}
          >
            {date}
          </span>
          <div className="flex flex-col gap-3">
            <h5 className="text-4xl font-semibold transition-colors duration-300 text-content-100">
              {title}
            </h5>
            <p className="text-content-70 text-lg">{description}</p>
          </div>
        </div>
      </div>
    );
  },
);

MapItem.displayName = "MapItem";
