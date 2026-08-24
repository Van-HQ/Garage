"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";
import { X } from "lucide-react";
import { computeMonthlyMiles, type TrendPoint } from "@/lib/mileage-trend";

type Mode = "care" | "monthly";

const dateFmt = (iso: string) => new Date(iso).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });

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

        <p className="text-[11px] text-center text-muted -mt-1">Scroll for more history · tap a point for details</p>
      </div>
    </div>
  );
}

/** Small floating card anchored above the active point, clamped inside [0, width]. */
function ScrubTooltip({ x, width, children }: { x: number; width: number; children: ReactNode }) {
  const tooltipWidth = 148;
  const left = Math.min(Math.max(x - tooltipWidth / 2, 0), width - tooltipWidth);
  return (
    <div
      className="absolute top-0 glass-panel rounded-xl px-3 py-2 pointer-events-none"
      style={{ left, width: tooltipWidth }}
    >
      {children}
    </div>
  );
}

function ExpandedCareChart({ points }: { points: TrendPoint[] }) {
  const [active, setActive] = useState<number | null>(null);
  const svgRef = useRef<SVGSVGElement>(null);

  const pointGap = 60;
  const padX = 24;
  const padTop = 44;
  const padBottom = 28;
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

  function handleTap(e: React.MouseEvent<SVGSVGElement>) {
    const rect = svgRef.current?.getBoundingClientRect();
    if (!rect) return;
    const x = e.clientX - rect.left;
    let nearest = 0;
    let nearestDist = Infinity;
    coords.forEach(([cx], i) => {
      const d = Math.abs(cx - x);
      if (d < nearestDist) {
        nearestDist = d;
        nearest = i;
      }
    });
    setActive(nearest);
  }

  const activePoint = active != null ? points[active] : null;
  const activeCoord = active != null ? coords[active] : null;

  return (
    <div style={{ width }}>
      <div className="flex items-baseline justify-between mb-2 text-[11px] font-semibold text-muted tabular-nums">
        <span>{min.toLocaleString()} mi</span>
        <span className="flex items-center gap-1">
          <span className="w-1.5 h-1.5 rounded-full inline-block" style={{ background: "var(--status-soon)" }} />
          {serviceCount} service{serviceCount === 1 ? "" : "s"}
        </span>
        <span>{max.toLocaleString()} mi</span>
      </div>

      <div className="relative">
      <svg ref={svgRef} width={width} height={height} viewBox={`0 0 ${width} ${height}`} onClick={handleTap} className="cursor-pointer">
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
          const isActive = i === active;
          return (
            <circle
              key={i}
              cx={x}
              cy={y}
              r={isActive ? 5.5 : isService ? 4 : 2.5}
              fill={isService ? "var(--status-soon)" : "var(--background-elevated)"}
              stroke={isService ? "var(--background-elevated)" : "var(--accent)"}
              strokeWidth={isActive ? 2 : 1.5}
            />
          );
        })}

        {activeCoord && (
          <line x1={activeCoord[0]} y1={padTop - 8} x2={activeCoord[0]} y2={height - padBottom} stroke="var(--accent)" strokeWidth="1" strokeDasharray="2 3" />
        )}

        <text x={padX} y={height - 6} fontSize="9" fill="var(--muted)">
          {dateFmt(points[0].date)}
        </text>
        <text x={width - padX} y={height - 6} textAnchor="end" fontSize="9" fill="var(--muted)">
          {dateFmt(points[points.length - 1].date)}
        </text>
      </svg>

      {activePoint && activeCoord && (
        <ScrubTooltip x={activeCoord[0]} width={width}>
          <p className="text-[11px] font-semibold">{dateFmt(activePoint.date)}</p>
          <p className="text-[11px] text-muted mt-0.5">{activePoint.mileage.toLocaleString()} mi</p>
          {activePoint.kind === "maintenance" ? (
            <p className="text-[11px] font-medium mt-1 flex items-center gap-1.5" style={{ color: "var(--status-soon)" }}>
              <span className="w-1.5 h-1.5 rounded-full inline-block shrink-0" style={{ background: "var(--status-soon)" }} />
              {activePoint.label ?? "Service"}
            </p>
          ) : (
            <p className="text-[11px] text-muted mt-1">Odometer check-in</p>
          )}
        </ScrubTooltip>
      )}
      </div>
    </div>
  );
}

function ExpandedMonthlyChart({ points }: { points: TrendPoint[] }) {
  const [active, setActive] = useState<number | null>(null);
  const svgRef = useRef<SVGSVGElement>(null);
  const data = computeMonthlyMiles(points, 60);

  if (data.length < 2) {
    return <div className="h-40 flex items-center justify-center text-xs text-muted">Not enough months of data yet</div>;
  }

  const pointGap = 56;
  const padX = 24;
  const padTop = 44;
  const padBottom = 28;
  const height = 220;
  const width = Math.max(320, padX * 2 + (data.length - 1) * pointGap);
  const max = Math.max(...data.map((d) => d.miles), 1);

  const coords = data.map((d, i) => {
    const x = padX + i * pointGap;
    const y = height - padBottom - (d.miles / max) * (height - padTop - padBottom);
    return [x, y] as const;
  });

  const linePath = coords.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x},${y}`).join(" ");

  function handleTap(e: React.MouseEvent<SVGSVGElement>) {
    const rect = svgRef.current?.getBoundingClientRect();
    if (!rect) return;
    const x = e.clientX - rect.left;
    let nearest = 0;
    let nearestDist = Infinity;
    coords.forEach(([cx], i) => {
      const d = Math.abs(cx - x);
      if (d < nearestDist) {
        nearestDist = d;
        nearest = i;
      }
    });
    setActive(nearest);
  }

  const activeData = active != null ? data[active] : null;
  const activeCoord = active != null ? coords[active] : null;

  return (
    <div style={{ width }}>
      <div className="flex items-baseline justify-between mb-2 text-[11px] font-semibold text-muted tabular-nums">
        <span>0 mi</span>
        <span>{max.toLocaleString()} mi / mo</span>
      </div>

      <div className="relative">
      <svg ref={svgRef} width={width} height={height} viewBox={`0 0 ${width} ${height}`} onClick={handleTap} className="cursor-pointer">
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
          const isActive = i === active;
          const isLast = i === coords.length - 1;
          return (
            <circle
              key={i}
              cx={x}
              cy={y}
              r={isActive ? 5.5 : isLast ? 3 : 1.75}
              fill={isLast ? "var(--accent)" : "var(--background-elevated)"}
              stroke="var(--accent)"
              strokeWidth={isActive ? 2 : isLast ? 0 : 1.5}
            />
          );
        })}

        {activeCoord && (
          <line x1={activeCoord[0]} y1={padTop - 8} x2={activeCoord[0]} y2={height - padBottom} stroke="var(--accent)" strokeWidth="1" strokeDasharray="2 3" />
        )}

        <text x={padX} y={height - 6} fontSize="9" fill="var(--muted)">
          {data[0].label}
        </text>
        <text x={width - padX} y={height - 6} textAnchor="end" fontSize="9" fill="var(--muted)">
          {data[data.length - 1].label}
        </text>
      </svg>

      {activeData && activeCoord && (
        <ScrubTooltip x={activeCoord[0]} width={width}>
          <p className="text-[11px] font-semibold">{activeData.fullLabel}</p>
          <p className="text-[11px] text-muted mt-0.5">{activeData.miles.toLocaleString()} mi driven</p>
        </ScrubTooltip>
      )}
      </div>
    </div>
  );
}
