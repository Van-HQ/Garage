"use client";

import { useEffect, useRef, useState } from "react";
import { X } from "lucide-react";
import { computeMonthlyMiles, type TrendPoint } from "@/lib/mileage-trend";

type Mode = "care" | "monthly";

const dateFmt = (iso: string) => new Date(iso).toLocaleDateString(undefined, { month: "short", day: "numeric" });

export default function ChartExpandModal({
  points,
  vehicleName,
  initialMode,
  onClose,
}: {
  points: TrendPoint[];
  vehicleName: string;
  initialMode: Mode;
  onClose: () => void;
}) {
  const [mode, setMode] = useState<Mode>(initialMode);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = scrollRef.current;
    if (el) el.scrollLeft = el.scrollWidth;
  }, [mode]);

  return (
    <div className="fixed inset-0 z-[60] flex items-end justify-center">
      <button className="absolute inset-0 bg-black/55 backdrop-blur-sm" onClick={onClose} aria-label="Close" />
      <div className="relative w-full max-w-md glass-panel rounded-t-[28px] rounded-b-none px-5 pt-4 pb-[max(1.25rem,env(safe-area-inset-bottom))] flex flex-col gap-4 max-h-[82vh]">
        <div className="w-9 h-1 rounded-full bg-[var(--muted)] opacity-40 mx-auto" />

        <div className="flex items-center justify-between">
          <div>
            <p className="text-xs font-medium tracking-[0.1em] uppercase text-muted">{vehicleName}</p>
            <h2 className="text-lg font-semibold tracking-tight mt-0.5">Mileage</h2>
          </div>
          <button onClick={onClose} className="glass-panel w-8 h-8 rounded-full flex items-center justify-center text-muted shrink-0" aria-label="Close">
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="flex justify-center">
          <div className="glass-panel rounded-full p-0.5 flex gap-0.5">
            {([
              ["care", "Care"],
              ["monthly", "Monthly"],
            ] as const).map(([key, label]) => (
              <button
                key={key}
                onClick={() => setMode(key)}
                className="text-xs font-semibold px-3.5 py-1.5 rounded-full transition-colors"
                style={{
                  background: mode === key ? "var(--accent)" : "transparent",
                  color: mode === key ? "var(--accent-foreground)" : "var(--muted)",
                }}
              >
                {label}
              </button>
            ))}
          </div>
        </div>

        <div ref={scrollRef} className="overflow-x-auto no-scrollbar -mx-5 px-5">
          {mode === "care" ? <ExpandedCareChart points={points} /> : <ExpandedMonthlyChart points={points} />}
        </div>

        <p className="text-[11px] text-center text-muted -mt-1">Scroll to see more history</p>
      </div>
    </div>
  );
}

function ExpandedCareChart({ points }: { points: TrendPoint[] }) {
  const pointGap = 60;
  const padX = 24;
  const padTop = 20;
  const padBottom = 36;
  const height = 220;
  const width = Math.max(320, padX * 2 + (points.length - 1) * pointGap);

  const miles = points.map((p) => p.mileage);
  const min = Math.min(...miles);
  const max = Math.max(...miles);
  const range = Math.max(max - min, 1);

  const coords = points.map((p, i) => {
    const x = padX + i * pointGap;
    const y = height - padBottom - ((p.mileage - min) / range) * (height - padTop - padBottom);
    return [x, y] as const;
  });

  const linePath = coords.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x},${y}`).join(" ");
  const serviceCount = points.filter((p) => p.kind === "maintenance").length;

  return (
    <div>
      <div className="flex items-baseline justify-between mb-2 text-[11px] font-semibold text-muted tabular-nums" style={{ width }}>
        <span>{min.toLocaleString()} mi</span>
        <span className="flex items-center gap-1">
          <span className="w-1.5 h-1.5 rounded-full inline-block" style={{ background: "var(--status-soon)" }} />
          {serviceCount} service{serviceCount === 1 ? "" : "s"}
        </span>
        <span>{max.toLocaleString()} mi</span>
      </div>

      <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
        {[0.25, 0.5, 0.75].map((f) => (
          <line
            key={f}
            x1={padX}
            y1={padTop + (height - padTop - padBottom) * f}
            x2={width - padX}
            y2={padTop + (height - padTop - padBottom) * f}
            stroke="var(--glass-border)"
            strokeWidth="1"
            strokeDasharray="2 3"
          />
        ))}

        <path d={linePath} fill="none" stroke="var(--accent)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />

        {coords.map(([x, y], i) => {
          const p = points[i];
          const isService = p.kind === "maintenance";
          return (
            <g key={i}>
              <circle
                cx={x}
                cy={y}
                r={isService ? 4 : 2.5}
                fill={isService ? "var(--status-soon)" : "var(--background-elevated)"}
                stroke={isService ? "var(--background-elevated)" : "var(--accent)"}
                strokeWidth={isService ? 1.5 : 1.5}
              />
              <text x={x} y={height - 14} textAnchor="middle" fontSize="9" fill="var(--muted)">
                {dateFmt(p.date)}
              </text>
              <text x={x} y={y - 10} textAnchor="middle" fontSize="9" fontWeight="600" fill="var(--foreground)">
                {p.mileage.toLocaleString()}
              </text>
            </g>
          );
        })}
      </svg>
    </div>
  );
}

function ExpandedMonthlyChart({ points }: { points: TrendPoint[] }) {
  const data = computeMonthlyMiles(points, 60);

  if (data.length === 0) {
    return <div className="h-40 flex items-center justify-center text-xs text-muted">Not enough months of data yet</div>;
  }

  const barWidth = 40;
  const gap = 18;
  const padX = 24;
  const padTop = 24;
  const padBottom = 24;
  const height = 220;
  const width = Math.max(320, padX * 2 + data.length * barWidth + (data.length - 1) * gap);
  const max = Math.max(...data.map((d) => d.miles), 1);

  return (
    <div>
      <div className="flex items-baseline justify-between mb-2 text-[11px] font-semibold text-muted tabular-nums" style={{ width }}>
        <span>0 mi</span>
        <span>{max.toLocaleString()} mi / mo</span>
      </div>

      <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
        {data.map((d, i) => {
          const barH = Math.max((d.miles / max) * (height - padTop - padBottom), d.miles > 0 ? 2 : 0);
          const x = padX + i * (barWidth + gap);
          const isLast = i === data.length - 1;
          return (
            <g key={i}>
              <rect
                x={x}
                y={height - padBottom - barH}
                width={barWidth}
                height={barH}
                rx={4}
                fill="var(--accent)"
                opacity={isLast ? 1 : 0.55}
              />
              <text x={x + barWidth / 2} y={height - padBottom - barH - 8} textAnchor="middle" fontSize="9" fontWeight="600" fill="var(--foreground)">
                {d.miles.toLocaleString()}
              </text>
              <text x={x + barWidth / 2} y={height - 8} textAnchor="middle" fontSize="9" fill="var(--muted)">
                {d.label}
              </text>
            </g>
          );
        })}
      </svg>
    </div>
  );
}
