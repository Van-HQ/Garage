import type { TrendPoint } from "@/lib/mileage-trend";

const dateFmt = (iso: string) => new Date(iso).toLocaleDateString(undefined, { month: "short", day: "numeric" });

export default function MileageSparkline({ points }: { points: TrendPoint[] }) {
  if (points.length < 2) return null;

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

  return (
    <div className="w-full">
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

        {coords.map(([x, y], i) => (
          <circle
            key={i}
            cx={x}
            cy={y}
            r={i === coords.length - 1 ? 3 : 1.75}
            fill={i === coords.length - 1 ? "var(--accent)" : "var(--background-elevated)"}
            stroke="var(--accent)"
            strokeWidth={i === coords.length - 1 ? 0 : 1.5}
          />
        ))}
      </svg>

      <div className="flex items-baseline justify-between px-0.5 mt-1">
        <span className="text-[10px] font-medium text-muted">{dateFmt(points[0].date)}</span>
        <span className="text-[10px] font-medium text-muted">{points.length} readings</span>
        <span className="text-[10px] font-medium text-muted">{dateFmt(points[points.length - 1].date)}</span>
      </div>
    </div>
  );
}
