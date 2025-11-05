"use client";

import { useRef } from "react";
import { motion, MotionValue, useScroll, useTransform } from "motion/react";

const Dot = ({
  dotIndex,
  filledDots,
  scrollYProgress,
}: {
  dotIndex: number;
  filledDots: number;
  scrollYProgress: MotionValue<number>;
}) => {
  const isFilled = dotIndex < filledDots;

  const dotThreshold = filledDots > 0 ? dotIndex / filledDots : 0;
  const dotOpacity = useTransform(
    scrollYProgress,
    [0, Math.min(dotThreshold + 0.05, 1), 1],
    [0.2, isFilled ? 1 : 0.2, isFilled ? 1 : 0.2],
  );

  return (
    <motion.div
      className="size-0.5 rounded-full bg-foreground"
      style={{ opacity: dotOpacity }}
    />
  );
};

export const DotBar = ({ progress }: { progress: number }) => {
  const totalDots = 25;
  const filledDots = Math.round(totalDots * progress);
  const containerRef = useRef<HTMLDivElement>(null);

  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start 0.8", "end 0.1"],
  });

  return (
    <div ref={containerRef} className="flex flex-col gap-1">
      {Array.from({ length: 5 }).map((_, rowIndex) => (
        <div key={rowIndex} className="flex items-center gap-1">
          {Array.from({ length: totalDots }).map((_, dotIndex) => (
            <Dot
              key={dotIndex}
              dotIndex={dotIndex}
              filledDots={filledDots}
              scrollYProgress={scrollYProgress}
            />
          ))}
        </div>
      ))}
    </div>
  );
};
