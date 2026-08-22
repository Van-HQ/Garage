"use client";

import { useState } from "react";
import { computeMonthlyMiles, type TrendPoint } from "@/lib/mileage-trend";
import ChartExpandModal from "@/components/ChartExpandModal";

const dateFmt = (iso: string) => new Date(iso).toLocaleDateString(undefined, { month: "short", day: "numeric" });

type Mode = "care" | "monthly";

export default function MileageSparkline({ points, vehicleName }: { points: TrendPoint[]; vehicleName?: string }) {
  const [mode, setMode] = useState<Mode>("care");
  const [expanded, setExpanded] = useState(false);

  if (points.length < 2) return null;

  return (
    <div className="w-full">
      <div className="flex justify-end mb-1.5">
        <div className="glass-panel rounded-full p-0.5 flex gap-0.5">
          {([
            ["care", "Care"],
            ["monthly", "Monthly"],
          ] as const).map(([key, label]) => (
            <button
              key={key}
              onClick={() => setMode(key)}
              className="text-[10px] font-semibold px-2.5 py-1 rounded-full transition-colors"
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

      <button onClick={() => setExpanded(true)} className="w-full text-left active:opacity-75 transition-opacity" aria-label="Expand mileage chart">
        {mode === "care" ? <CareTrend points={points} /> : <MonthlyBars points={points} />}
      </button>

      {expanded && (
        <ChartExpandModal points={points} vehicleName={vehicleName ?? "Mileage"} initialMode={mode} onClose={() => setExpanded(false)} />
      )}
    </div>
  );
}

function CareTrend({ points }: { points: TrendPoint[] }) {
  const width = 300;
  const height = 64;
  const padX = 4;
  const padY = 10;

  const miles = points.map((p) => p.mileage);
  const min = Math.min(...miles);
  const max = Math.max(...miles);
  const range = Math.max(max - min, 1);
  const stepX = (width - padX * 2) / (points.length - 1);

  const coords = points.map((p, i) => {
    const x = padX + i * stepX;
    const y = height - padY - ((p.mileage - min) / range) * (height - padY * 2);
    return [x, y] as const;
  });

  const linePath = coords.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x},${y}`).join(" ");
  const [lastX] = coords[coords.length - 1];
  const [firstX] = coords[0];
  const areaPath = `${linePath} L${lastX},${height} L${firstX},${height} Z`;
  const midY = height - padY - (height - padY * 2) / 2;
  const serviceCount = points.filter((p) => p.kind === "maintenance").length;

  return (
    <>
      <div className="flex items-baseline justify-between px-0.5 mb-1">
        <span className="text-[10px] font-semibold text-muted tabular-nums">{min.toLocaleString()} mi</span>
        <span className="text-[10px] font-semibold text-muted tabular-nums">{max.toLocaleString()} mi</span>
      </div>

      <svg viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none" className="w-full h-16">
        <defs>
          <linearGradient id="sparkFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="var(--accent)" stopOpacity="0.22" />
            <stop offset="100%" stopColor="var(--accent)" stopOpacity="0" />
          </linearGradient>
        </defs>

        <line x1={padX} y1={midY} x2={width - padX} y2={midY} stroke="var(--glass-border)" strokeWidth="1" strokeDasharray="2 3" />

        <path d={areaPath} fill="url(#sparkFill)" stroke="none" />
        <path d={linePath} fill="none" stroke="var(--accent)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />

        {coords.map(([x, y], i) => {
          const isService = points[i].kind === "maintenance";
          const isLast = i === coords.length - 1;
          if (isService) {
            return <circle key={i} cx={x} cy={y} r={isLast ? 3.5 : 3} fill="var(--status-soon)" stroke="var(--background-elevated)" strokeWidth="1.5" />;
          }
          return (
            <circle
              key={i}
              cx={x}
              cy={y}
              r={isLast ? 3 : 1.75}
              fill={isLast ? "var(--accent)" : "var(--background-elevated)"}
              stroke="var(--accent)"
              strokeWidth={isLast ? 0 : 1.5}
            />
          );
        })}
      </svg>

      <div className="flex items-baseline justify-between px-0.5 mt-1">
        <span className="text-[10px] font-medium text-muted">{dateFmt(points[0].date)}</span>
        <span className="text-[10px] font-medium text-muted flex items-center gap-1">
          <span className="w-1.5 h-1.5 rounded-full inline-block" style={{ background: "var(--status-soon)" }} />
          {serviceCount} service{serviceCount === 1 ? "" : "s"}
        </span>
        <span className="text-[10px] font-medium text-muted">{dateFmt(points[points.length - 1].date)}</span>
      </div>
    </>
  );
}

function MonthlyBars({ points }: { points: TrendPoint[] }) {
  const data = computeMonthlyMiles(points);

  if (data.length === 0) {
    return <div className="h-16 flex items-center justify-center text-xs text-muted">Not enough months of data yet</div>;
  }

  const width = 300;
  const height = 64;
  const gap = 10;
  const barWidth = (width - gap * (data.length - 1)) / data.length;
  const max = Math.max(...data.map((d) => d.miles), 1);

  return (
    <>
      <div className="flex items-baseline justify-between px-0.5 mb-1">
        <span className="text-[10px] font-semibold text-muted tabular-nums">0 mi</span>
        <span className="text-[10px] font-semibold text-muted tabular-nums">{max.toLocaleString()} mi / mo</span>
      </div>

      <svg viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none" className="w-full h-16">
        {data.map((d, i) => {
          const barH = Math.max((d.miles / max) * (height - 4), d.miles > 0 ? 2 : 0);
          const x = i * (barWidth + gap);
          const isLast = i === data.length - 1;
          return (
            <rect
              key={i}
              x={x}
              y={height - barH}
              width={barWidth}
              height={barH}
              rx={3}
              fill="var(--accent)"
              opacity={isLast ? 1 : 0.5}
            />
          );
        })}
      </svg>

      <div className="flex items-baseline justify-between px-0.5 mt-1">
        {data.map((d, i) => (
          <span key={i} className="text-[10px] font-medium text-muted" style={{ width: barWidth }}>
            {d.label}
          </span>
        ))}
      </div>
    </>
  );
}
