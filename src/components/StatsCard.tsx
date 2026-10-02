"use client";

import { useMemo } from "react";
import type { MaintenanceLog, MileageLog, Vehicle } from "@/lib/types";
import { computeMileageTrend, computeMonthlyStats } from "@/lib/mileage-trend";

const fmtDate = (iso: string) => new Date(iso).toLocaleDateString(undefined, { month: "short", day: "numeric" });

function signed(n: number) {
  return `${n > 0 ? "+" : n < 0 ? "−" : ""}${Math.abs(n).toLocaleString()}`;
}

export default function StatsCard({
  vehicle,
  logs,
  mileageLogs,
}: {
  vehicle: Vehicle;
  logs: MaintenanceLog[];
  mileageLogs: MileageLog[];
}) {
  const points = useMemo(() => computeMileageTrend(vehicle, logs, mileageLogs), [vehicle, logs, mileageLogs]);
  const months = useMemo(() => computeMonthlyStats(points), [points]);

  if (points.length < 2) return null;

  const first = points[0];
  const last = points[points.length - 1];
  const total = last.mileage - first.mileage;
  const avg = months.length > 0 ? Math.round(months.reduce((sum, m) => sum + m.miles, 0) / months.length) : null;

  return (
    <div className="flex flex-col gap-3">
      <h3 className="text-sm font-semibold text-muted px-1">Stats · {vehicle.name}</h3>
      <div className="glass-panel rounded-3xl px-4 py-4 flex flex-col gap-4">
        <div className="flex items-end justify-between gap-3">
          <div className="min-w-0">
            <p className="text-xs text-muted">Since you started tracking</p>
            <p className="text-[28px] leading-tight font-bold tabular-nums">{total.toLocaleString()} mi</p>
          </div>
          <p className="text-xs text-muted text-right tabular-nums shrink-0">
            {fmtDate(first.date)} → {fmtDate(last.date)}
            <br />
            {first.mileage.toLocaleString()} → {last.mileage.toLocaleString()}
          </p>
        </div>

        {months.length > 0 && (
          <div className="flex flex-col">
            <div className="flex text-[11px] font-semibold uppercase tracking-wide text-muted pb-1.5">
              <span className="w-12">Month</span>
              <span className="flex-1 text-right">Miles</span>
              <span className="flex-1 text-right">vs. prior</span>
            </div>
            {months.map((m) => {
              const color =
                m.changeMiles == null || m.changeMiles === 0
                  ? "var(--muted)"
                  : m.changeMiles > 0
                    ? "var(--status-ok)"
                    : "var(--status-overdue)";
              return (
                <div key={m.fullLabel} className="flex items-baseline text-sm tabular-nums py-1.5 border-t border-white/5">
                  <span className="w-12 text-muted">{m.label}</span>
                  <span className="flex-1 text-right font-medium">{m.miles.toLocaleString()}</span>
                  <span className="flex-1 text-right" style={{ color }}>
                    {m.changeMiles == null ? (
                      "—"
                    ) : (
                      <>
                        {m.changePct != null ? `${m.changePct > 0 ? "▲" : m.changePct < 0 ? "▼" : ""} ${signed(m.changePct)}%` : "—"}
                        <span className="text-xs text-muted"> ({signed(m.changeMiles)})</span>
                      </>
                    )}
                  </span>
                </div>
              );
            })}
            {avg != null && (
              <p className="text-xs text-muted pt-2 border-t border-white/5">Average {avg.toLocaleString()} mi/mo</p>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
