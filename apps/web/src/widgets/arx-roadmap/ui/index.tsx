"use client";

import { useEffect, useRef, useState } from "react";
import { Roadmap } from "./roadmap";

export const ArxRoadmap = () => {
  const sectionRef = useRef<HTMLDivElement>(null);
  const leftColumnRef = useRef<HTMLDivElement>(null);
  const [isInViewport, setIsInViewport] = useState(false);

  useEffect(() => {
    const section = sectionRef.current;
    if (!section) return;

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          setIsInViewport(entry.isIntersecting);
        });
      },
      {
        threshold: 0.1,
        rootMargin: "100px 0px -100px 0px",
      },
    );

    observer.observe(section);

    return () => {
      observer.disconnect();
    };
  }, []);

  return (
    <div
      ref={sectionRef}
      className="grid grid-cols-1 gap-10 px-4 md:grid-cols-2 md:px-0 md:py-20"
    >
      <div
        ref={leftColumnRef}
        className={`flex flex-col gap-6 md:gap-8 ${
          isInViewport ? "md:sticky md:top-40 md:self-start" : ""
        }`}
        style={{
          transform: isInViewport ? "translateY(0)" : "translateY(-8px)",
          transition: "transform 700ms cubic-bezier(0.4, 0, 0.2, 1)",
        }}
      >
        <h2 className="text-content-100 text-[38px] leading-[105%] font-semibold md:text-[60px]">
          ARX Hyper
          <br /> Roadmap
        </h2>
        <h2 className="text-content-70 max-w-[484px] text-base leading-[160%] md:text-xl">
          The ARX journey unfolds step by step — from secure messaging to a
          self-sustaining network with wallet, nodes, and governance.
        </h2>
      </div>
      <Roadmap />
    </div>
  );
};
