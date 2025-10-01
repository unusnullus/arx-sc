"use client";
import { useEffect, useMemo, useRef, useState } from "react";

type Milestone = {
  lane: "Product" | "Network" | "Token";
  label: string;
  t: number;
};

const MILESTONES: Milestone[] = [
  { lane: "Product", label: "Messenger Alpha", t: 0.1 },
  { lane: "Network", label: "Node Incentives", t: 0.25 },
  { lane: "Token", label: "$ARX Sale", t: 0.3 },
  { lane: "Product", label: "VPN/eSIM", t: 0.5 },
  { lane: "Network", label: "Mainnet Launch", t: 0.6 },
  { lane: "Token", label: "Governance", t: 0.8 },
];

export default function Roadmap() {
  const svgRef = useRef<SVGSVGElement>(null);
  const [progress, setProgress] = useState(0);
  const prefersReduced = useMemo(
    () =>
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches,
    [],
  );

  useEffect(() => {
    if (prefersReduced) return;
    const onScroll = () => {
      const el = svgRef.current;
      if (!el) return;
      const rect = el.getBoundingClientRect();
      const vh = window.innerHeight || 1;
      const p =
        1 -
        Math.min(
          1,
          Math.max(0, (rect.top + rect.height * 0.2) / (vh + rect.height)),
        );
      setProgress(p);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, [prefersReduced]);

  const strokeLen = 1200;
  const dash = prefersReduced
    ? undefined
    : `${strokeLen * progress} ${strokeLen}`;

  return (
    <div className="relative py-24">
      <svg
        ref={svgRef}
        className="w-full"
        viewBox="0 0 1200 600"
        preserveAspectRatio="xMidYMid meet"
      >
        <defs>
          <linearGradient id="grad" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0%" stopColor="#00FFFF" />
            <stop offset="100%" stopColor="#00FF88" />
          </linearGradient>
        </defs>
        <path
          id="path-product"
          d="M 50 150 C 350 100 850 200 1150 150"
          fill="none"
          stroke="url(#grad)"
          strokeWidth="4"
          strokeDasharray={dash}
        />
        <path
          id="path-network"
          d="M 50 300 C 350 250 850 350 1150 300"
          fill="none"
          stroke="url(#grad)"
          strokeWidth="4"
          strokeDasharray={dash}
          opacity="0.75"
        />
        <path
          id="path-token"
          d="M 50 450 C 350 400 850 500 1150 450"
          fill="none"
          stroke="url(#grad)"
          strokeWidth="4"
          strokeDasharray={dash}
          opacity="0.5"
        />

        {MILESTONES.map((m, i) => {
          const pathId =
            m.lane === "Product"
              ? "path-product"
              : m.lane === "Network"
                ? "path-network"
                : "path-token";
          return (
            <MilestoneDot
              key={i}
              pathId={pathId}
              t={m.t}
              label={`${m.lane}: ${m.label}`}
            />
          );
        })}
      </svg>
    </div>
  );
}

function MilestoneDot({
  pathId,
  t,
  label,
}: {
  pathId: string;
  t: number;
  label: string;
}) {
  const ref = useRef<SVGCircleElement>(null);
  const [pos, setPos] = useState<{ x: number; y: number } | null>(null);

  useEffect(() => {
    const path = document.getElementById(pathId) as SVGPathElement | null;
    if (!path) return;
    const len = path.getTotalLength();
    const p = path.getPointAtLength(len * t);
    setPos({ x: p.x, y: p.y });
  }, [pathId, t]);

  if (!pos) return null;
  return (
    <g>
      <circle ref={ref} cx={pos.x} cy={pos.y} r="6" fill="#00FFFF" />
      <text x={pos.x + 10} y={pos.y - 10} fill="#A0A0A0" fontSize="12">
        {label}
      </text>
    </g>
  );
}
