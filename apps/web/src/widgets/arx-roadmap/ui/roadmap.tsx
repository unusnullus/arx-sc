"use client";

import { useEffect, useRef, useState } from "react";
import { roadmapData } from "./data";
import { MapItem } from "./map-item";

export const Roadmap = () => {
  const containerRef = useRef<HTMLDivElement>(null);
  const itemRefs = useRef<(HTMLDivElement | null)[]>([]);
  const [activeIndex, setActiveIndex] = useState(0);
  const [progressValues, setProgressValues] = useState<number[]>(
    new Array(roadmapData.length).fill(0),
  );

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const updateProgress = () => {
      const viewportCenter = window.scrollY + window.innerHeight / 2;

      let newActiveIndex = 0;
      let minDistance = Infinity;

      itemRefs.current.forEach((item, index) => {
        if (!item) return;

        const itemRect = item.getBoundingClientRect();
        const itemTop = itemRect.top + window.scrollY;
        const itemCenter = itemTop + itemRect.height / 2;

        const distance = Math.abs(itemCenter - viewportCenter);
        if (distance < minDistance) {
          minDistance = distance;
          newActiveIndex = index;
        }
      });

      const newProgressValues: number[] = [];

      itemRefs.current.forEach((item, index) => {
        if (!item) {
          newProgressValues.push(0);
          return;
        }

        const itemRect = item.getBoundingClientRect();
        const itemBottom = itemRect.bottom + window.scrollY;

        if (index < roadmapData.length - 1) {
          const nextItem = itemRefs.current[index + 1];
          if (nextItem) {
            const nextItemRect = nextItem.getBoundingClientRect();
            const nextItemTop = nextItemRect.top + window.scrollY;
            const lineHeight = nextItemTop - itemBottom;

            if (index < newActiveIndex) {
              newProgressValues.push(100);
            } else if (index === newActiveIndex && lineHeight > 0) {
              const scrolledFromItem = viewportCenter - itemBottom;
              const progress = Math.max(
                0,
                Math.min(100, (scrolledFromItem / lineHeight) * 100),
              );
              newProgressValues.push(progress);
            } else {
              newProgressValues.push(0);
            }
          } else {
            newProgressValues.push(0);
          }
        } else {
          if (index < newActiveIndex || index === newActiveIndex) {
            newProgressValues.push(100);
          } else {
            newProgressValues.push(0);
          }
        }
      });

      setActiveIndex(newActiveIndex);
      setProgressValues(newProgressValues);
    };

    const observers: IntersectionObserver[] = [];

    itemRefs.current.forEach((item) => {
      if (!item) return;

      const observer = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              updateProgress();
            }
          });
        },
        {
          root: null,
          threshold: [0, 0.1, 0.3, 0.5, 0.7, 1],
          rootMargin: "-50% 0px -50% 0px",
        },
      );

      observer.observe(item);
      observers.push(observer);
    });

    const handleScroll = () => {
      updateProgress();
    };

    window.addEventListener("scroll", handleScroll, { passive: true });
    updateProgress();

    return () => {
      window.removeEventListener("scroll", handleScroll);
      observers.forEach((observer) => observer.disconnect());
    };
  }, []);

  return (
    <div ref={containerRef} className="flex flex-col">
      {roadmapData.map((item, index) => (
        <MapItem
          key={index}
          ref={(el) => {
            itemRefs.current[index] = el;
          }}
          {...item}
          isActive={index === activeIndex}
          isPassed={index < activeIndex}
          progress={progressValues[index] || 0}
          isLast={index === roadmapData.length - 1}
        />
      ))}
    </div>
  );
};
