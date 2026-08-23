"use client";

import Link from "next/link";
import { X } from "lucide-react";
import type { MaintenanceLog, Vehicle } from "@/lib/types";
import type { MaintenanceStatusItem } from "@/lib/maintenance-status";
import { STATUS_COLOR } from "@/components/StatusRow";
import { historyForType, computeIntervalAverage, totalCost } from "@/lib/care-detail";
import { MAINTENANCE_ICONS } from "@/lib/maintenance-icons";

const dateFmt = (iso: string) => new Date(iso).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });

export default function CareItemDetailModal({
  item,
  vehicle,
  logs,
  onClose,
  onEditBaseline,
  onOpenLog,
}: {
  item: MaintenanceStatusItem;
  vehicle: Vehicle;
  logs: MaintenanceLog[];
  onClose: () => void;
  onEditBaseline: () => void;
  onOpenLog: (log: MaintenanceLog) => void;
}) {
  const { type } = item;
  const Icon = MAINTENANCE_ICONS[type.icon] ?? MAINTENANCE_ICONS.wrench;
  const color = STATUS_COLOR[item.status];
  const history = historyForType(logs, vehicle, type);
  const { avgMiles, percentAheadMiles } = computeIntervalAverage(history, type);
  const cost = totalCost(history);

  let statusLine = "No reminder set for this item";
  if (item.milesRemaining != null || item.daysRemaining != null) {
    const overdue = (item.milesRemaining != null && item.milesRemaining <= 0) || (item.daysRemaining != null && item.daysRemaining <= 0);
    if (overdue) {
      statusLine =
        item.milesRemaining != null && item.milesRemaining <= 0
          ? `Overdue by ${Math.abs(item.milesRemaining).toLocaleString()} mi`
          : `Overdue by ${Math.abs(item.daysRemaining ?? 0)} days`;
    } else {
      const parts: string[] = [];
      if (item.dueMileage != null) parts.push(`${item.dueMileage.toLocaleString()} mi`);
      if (item.dueDate != null) parts.push(dateFmt(item.dueDate));
      statusLine = parts.length > 0 ? `Next due ${parts.join(" or ")}` : "On track";
    }
  } else if (item.lastLog) {
    statusLine = "Logged, no reminder set";
  }

  const hasInterval = type.interval_miles != null || type.interval_days != null;

  return (
    <div className="fixed inset-0 z-[60] flex items-end justify-center">
      <button className="absolute inset-0 bg-black/55 backdrop-blur-sm" onClick={onClose} aria-label="Close" />
      <div className="relative w-full max-w-md glass-panel rounded-t-[28px] rounded-b-none px-5 pt-4 pb-[max(1.25rem,env(safe-area-inset-bottom))] flex flex-col gap-4 max-h-[86vh] overflow-y-auto">
        <div className="w-9 h-1 rounded-full bg-[var(--muted)] opacity-40 mx-auto" />

        <div className="flex items-start justify-between gap-3">
          <div>
            <h2 className="text-lg font-semibold tracking-tight">{type.name}</h2>
            <p className="text-xs font-medium mt-1 flex items-center gap-1.5" style={{ color }}>
              <span className="w-1.5 h-1.5 rounded-full inline-block shrink-0" style={{ background: color }} />
              {statusLine}
            </p>
          </div>
          <button onClick={onClose} className="glass-panel w-7 h-7 rounded-full flex items-center justify-center text-muted shrink-0 mt-0.5" aria-label="Close">
            <X className="w-3.5 h-3.5" />
          </button>
        </div>

        <div className="flex gap-2.5">
          <div className="flex-1 bg-[var(--background)] border border-[var(--glass-border)] rounded-2xl px-3 py-2.5">
            <p className="text-[10px] font-semibold uppercase tracking-wide text-muted">Target</p>
            <p className="text-[15px] font-semibold mt-0.5">
              {type.interval_miles != null ? `${type.interval_miles.toLocaleString()} mi` : hasInterval ? "—" : "Not set"}
            </p>
            {type.interval_days != null && <p className="text-[11px] text-muted">or {type.interval_days} days</p>}
          </div>

          <div className="flex-1 bg-[var(--background)] border border-[var(--glass-border)] rounded-2xl px-3 py-2.5">
            <p className="text-[10px] font-semibold uppercase tracking-wide text-muted">Your average</p>
            <p className="text-[15px] font-semibold mt-0.5">{avgMiles != null ? `${avgMiles.toLocaleString()} mi` : "—"}</p>
            {percentAheadMiles != null && (
              <p className="text-[11px]" style={{ color: percentAheadMiles >= 0 ? "var(--status-ok)" : "var(--status-soon)" }}>
                {percentAheadMiles >= 0 ? `${percentAheadMiles}% ahead` : `${Math.abs(percentAheadMiles)}% behind`}
              </p>
            )}
          </div>

          <div className="flex-1 bg-[var(--background)] border border-[var(--glass-border)] rounded-2xl px-3 py-2.5">
            <p className="text-[10px] font-semibold uppercase tracking-wide text-muted">Spent</p>
            <p className="text-[15px] font-semibold mt-0.5">{cost > 0 ? `$${cost.toLocaleString()}` : "—"}</p>
            <p className="text-[11px] text-muted">
              {history.length} service{history.length === 1 ? "" : "s"}
            </p>
          </div>
        </div>

        {history.length > 0 ? (
          <div className="flex flex-col gap-2">
            <p className="text-xs font-semibold text-muted px-0.5">History</p>
            <div className="list-panel">
              {history.map((log) => (
                <button key={log.id} onClick={() => onOpenLog(log)} className="list-row active:opacity-70 w-full text-left">
                  <div
                    className="w-7 h-7 rounded-lg flex items-center justify-center shrink-0"
                    style={{ background: "color-mix(in srgb, var(--accent) 15%, transparent)", color: "var(--accent)" }}
                  >
                    <Icon className="w-3.5 h-3.5" strokeWidth={2} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-[15px] font-medium truncate">{dateFmt(log.performed_at)}</p>
                    <p className="text-xs text-muted truncate">
                      {log.mileage_at.toLocaleString()} mi{log.notes ? ` · ${log.notes}` : ""}
                    </p>
                  </div>
                  {log.cost != null && <span className="text-sm font-semibold shrink-0">${log.cost.toLocaleString()}</span>}
                </button>
              ))}
            </div>
          </div>
        ) : (
          <div className="flex flex-col gap-2">
            <div className="flex items-center justify-between px-0.5">
              <p className="text-xs font-semibold text-muted">Starting point</p>
              <button onClick={onEditBaseline} className="text-xs font-semibold text-accent">
                Edit
              </button>
            </div>
            <div className="form-panel">
              <div className="form-row" style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between" }}>
                <span className="text-[15px]">Baseline mileage</span>
                <span className="text-[15px] text-muted">{type.baseline_mileage != null ? `${type.baseline_mileage.toLocaleString()} mi` : "0 mi"}</span>
              </div>
              <div className="form-row" style={{ flexDirection: "row", alignItems: "center", justifyContent: "space-between" }}>
                <span className="text-[15px]">Baseline date</span>
                <span className="text-[15px] text-muted">{dateFmt(type.baseline_date ?? vehicle.created_at)}</span>
              </div>
            </div>
          </div>
        )}

        <Link
          href={`/log?vehicle=${vehicle.id}&type=${type.id}`}
          className="btn-accent rounded-2xl py-3.5 text-sm font-medium flex items-center justify-center gap-2"
        >
          Log this service
        </Link>
      </div>
    </div>
  );
}
