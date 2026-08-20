import type { CostBreakdown as CostBreakdownData } from "@/lib/cost";

export default function CostBreakdown({ data }: { data: CostBreakdownData }) {
  const max = Math.max(...data.byCategory.map((c) => c.amount), 1);

  return (
    <div className="flex flex-col gap-4">
      <div className="glass-panel rounded-3xl px-5 py-5 flex items-center justify-between gap-4">
        <div>
          <p className="text-xs font-medium tracking-wide uppercase text-muted">Total spent</p>
          <p className="text-3xl font-semibold tabular-nums tracking-tight mt-1">
            ${data.total.toLocaleString(undefined, { maximumFractionDigits: 0 })}
          </p>
        </div>
        <div className="text-right">
          <p className="text-xs font-medium tracking-wide uppercase text-muted">This year</p>
          <p className="text-lg font-semibold tabular-nums tracking-tight mt-1">
            ${data.thisYearTotal.toLocaleString(undefined, { maximumFractionDigits: 0 })}
          </p>
        </div>
      </div>

      {data.byCategory.length > 0 && (
        <div className="glass-panel rounded-3xl px-5 py-4 flex flex-col gap-3.5">
          {data.byCategory.map((c) => (
            <div key={c.category} className="flex flex-col gap-1.5">
              <div className="flex items-baseline justify-between gap-2">
                <span className="text-sm font-medium truncate">{c.label}</span>
                <span className="text-sm tabular-nums text-muted shrink-0">
                  ${c.amount.toLocaleString(undefined, { maximumFractionDigits: 0 })}
                </span>
              </div>
              <div className="h-2.5 rounded-full" style={{ background: "color-mix(in srgb, var(--muted) 22%, transparent)" }}>
                <div
                  className="h-full rounded-full"
                  style={{
                    width: `${Math.max((c.amount / max) * 100, 4)}%`,
                    background: "var(--accent)",
                  }}
                />
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
