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
        rootMargin: "0px",
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
      className="grid grid-cols-1 gap-10 py-20 md:grid-cols-2"
    >
      <div
        ref={leftColumnRef}
        className={`flex flex-col gap-8 transition-all duration-300 ${
          isInViewport ? "md:sticky md:top-40 md:self-start" : ""
        }`}
      >
        <h2 className="text-content-100 text-[60px] leading-[105%] font-semibold">
          ARX Hyper
          <br /> Roadmap
        </h2>
        <h2 className="text-content-70 max-w-[484px] text-xl leading-[160%]">
          The ARX journey unfolds step by step — from secure messaging to a
          self-sustaining network with wallet, nodes, and governance.
        </h2>
      </div>
      <Roadmap />
    </div>
  );
};
