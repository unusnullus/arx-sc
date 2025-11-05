"use client";

import { useRef } from "react";
import { motion, MotionValue, useScroll, useTransform } from "motion/react";

const text =
  "Introducing Arx — your private network. Powered by the ARX token, Arx unifies messaging, payments, and connectivity into one secure, self-governed ecosystem.";

const Letter = ({
  letter,
  index,
  totalLetters,
  scrollYProgress,
}: {
  letter: string;
  index: number;
  totalLetters: number;
  scrollYProgress: MotionValue<number>;
}) => {
  const letterProgress = index / totalLetters;
  const color = useTransform(
    scrollYProgress,
    [Math.max(0, letterProgress - 0.1), Math.min(1, letterProgress + 0.1)],
    ["rgba(255, 255, 255, 0.5)", "rgba(255, 255, 255, 1)"],
  );

  return (
    <motion.span style={{ color }} className="inline-block">
      {letter}
    </motion.span>
  );
};

const Word = ({
  word,
  startIndex,
  totalLetters,
  scrollYProgress,
}: {
  word: string;
  startIndex: number;
  totalLetters: number;
  scrollYProgress: MotionValue<number>;
}) => {
  const letters = word.split("");

  return (
    <span className="inline-block">
      {letters.map((letter, letterIndex) => (
        <Letter
          key={letterIndex}
          letter={letter}
          index={startIndex + letterIndex}
          totalLetters={totalLetters}
          scrollYProgress={scrollYProgress}
        />
      ))}
    </span>
  );
};

export const IntroArx = () => {
  const containerRef = useRef<HTMLDivElement>(null);

  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start 0.6", "end 0.6"],
  });

  const words = text.split(" ");
  const totalLetters = text.replace(/\s/g, "").length;

  return (
    <div ref={containerRef} className="flex justify-center">
      <h2 className="my-30 max-w-[1080px] text-center text-[44px] leading-[150%] font-semibold tracking-[-2%]">
        {words.map((word, wordIndex) => {
          const wordStartIndex = words
            .slice(0, wordIndex)
            .join("")
            .replace(/\s/g, "").length;

          const isLastWord = wordIndex === words.length - 1;

          return (
            <span key={wordIndex} className="inline">
              <Word
                word={word}
                startIndex={wordStartIndex}
                totalLetters={totalLetters}
                scrollYProgress={scrollYProgress}
              />
              {!isLastWord && <span className="inline-block">{"\u00A0"}</span>}
            </span>
          );
        })}
      </h2>
    </div>
  );
};
