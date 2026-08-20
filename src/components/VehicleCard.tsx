"use client";

import type { MaintenanceType, MaintenanceLog, Vehicle } from "@/lib/types";
import { computeMaintenanceStatus, projectedMileage } from "@/lib/maintenance-status";

export default function VehicleCard({
  vehicle,
  types,
  logs,
}: {
  vehicle: Vehicle;
  types: MaintenanceType[];
  logs: MaintenanceLog[];
}) {
  const miles = projectedMileage(vehicle);
  const status = computeMaintenanceStatus(vehicle, types, logs);
  const overdue = status.filter((s) => s.status === "overdue").length;
  const soon = status.filter((s) => s.status === "due-soon").length;

  return (
    <div className="w-full shrink-0 snap-center px-1">
      <div className="flex flex-col items-center text-center gap-1 pt-1 pb-2">
        <p className="text-[13px] font-semibold text-muted">
          {vehicle.name} · {vehicle.year} {vehicle.model}
        </p>

        <p className="text-[44px] leading-none font-bold tracking-tight tabular-nums mt-2">
          {miles.toLocaleString()}
        </p>
        <p className="text-[11px] font-semibold uppercase tracking-wide text-muted mt-1.5">
          Miles, estimated
        </p>

        <div className="flex items-center gap-2 mt-3">
          {overdue > 0 && (
            <span
              className="text-xs font-semibold px-3 py-1.5 rounded-full border"
              style={{ borderColor: "color-mix(in srgb, var(--status-overdue) 35%, transparent)", color: "var(--status-overdue)" }}
            >
              {overdue} overdue
            </span>
          )}
          {soon > 0 && (
            <span
              className="text-xs font-semibold px-3 py-1.5 rounded-full border"
              style={{ borderColor: "color-mix(in srgb, var(--status-soon) 35%, transparent)", color: "var(--status-soon)" }}
            >
              {soon} due soon
            </span>
          )}
          {overdue === 0 && soon === 0 && (
            <span
              className="text-xs font-semibold px-3 py-1.5 rounded-full border"
              style={{ borderColor: "color-mix(in srgb, var(--status-ok) 35%, transparent)", color: "var(--status-ok)" }}
            >
              All caught up
            </span>
          )}
        </div>
      </div>
    </div>
  );
}
