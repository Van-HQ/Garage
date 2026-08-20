import type { TrendPoint } from "@/lib/mileage-trend";

export default function MileageSparkline({ points }: { points: TrendPoint[] }) {
  if (points.length < 2) return null;

  const width = 300;
  const height = 52;
  const pad = 4;

  const miles = points.map((p) => p.mileage);
  const min = Math.min(...miles);
  const max = Math.max(...miles);
  const range = Math.max(max - min, 1);
  const stepX = (width - pad * 2) / (points.length - 1);

  const coords = points.map((p, i) => {
    const x = pad + i * stepX;
    const y = height - pad - ((p.mileage - min) / range) * (height - pad * 2);
    return [x, y] as const;
  });

  const linePath = coords.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x},${y}`).join(" ");
  const [lastX, lastY] = coords[coords.length - 1];
  const [firstX] = coords[0];
  const areaPath = `${linePath} L${lastX},${height} L${firstX},${height} Z`;

  return (
    <svg viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none" className="w-full h-[52px]">
      <defs>
        <linearGradient id="sparkFill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="var(--accent)" stopOpacity="0.22" />
          <stop offset="100%" stopColor="var(--accent)" stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={areaPath} fill="url(#sparkFill)" stroke="none" />
      <path d={linePath} fill="none" stroke="var(--accent)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx={lastX} cy={lastY} r="3" fill="var(--accent)" />
    </svg>
  );
}
