"use client";

import type { MaintenanceType, MaintenanceLog, Vehicle } from "@/lib/types";
import { computeMaintenanceStatus, projectedMileage } from "@/lib/maintenance-status";
import VehicleGlyph from "@/components/VehicleGlyph";

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
  const accent = vehicle.color || "var(--accent)";

  return (
    <div className="w-full shrink-0 snap-center px-1">
      <div
        className="card-surface rounded-[32px] px-7 pt-8 pb-7 flex flex-col items-center text-center gap-4 relative overflow-hidden"
        style={{
          background: `radial-gradient(140% 100% at 50% -20%, color-mix(in srgb, ${accent} 22%, transparent), transparent), var(--background-elevated)`,
        }}
      >
        <div
          className="glass-panel w-20 h-20 rounded-[26px] flex items-center justify-center p-3"
          style={{ color: accent }}
        >
          <VehicleGlyph icon={vehicle.icon} className="w-full h-full" />
        </div>

        <div className="flex flex-col gap-1">
          <p className="text-xs font-medium tracking-[0.14em] uppercase text-muted">
            {vehicle.year} {vehicle.make}
          </p>
          <h2 className="text-[28px] leading-tight font-semibold tracking-tight">{vehicle.name}</h2>
          <p className="text-sm text-muted">{vehicle.model}</p>
        </div>

        <div className="flex items-baseline gap-1.5 mt-1">
          <span className="text-3xl font-semibold tabular-nums tracking-tight">
            {miles.toLocaleString()}
          </span>
          <span className="text-sm text-muted">mi (est.)</span>
        </div>

        <div className="flex items-center gap-2 mt-1">
          {overdue > 0 && (
            <span
              className="text-xs font-medium px-3 py-1.5 rounded-full glass-input"
              style={{ color: "var(--status-overdue)" }}
            >
              {overdue} overdue
            </span>
          )}
          {soon > 0 && (
            <span
              className="text-xs font-medium px-3 py-1.5 rounded-full glass-input"
              style={{ color: "var(--status-soon)" }}
            >
              {soon} due soon
            </span>
          )}
          {overdue === 0 && soon === 0 && (
            <span
              className="text-xs font-medium px-3 py-1.5 rounded-full glass-input"
              style={{ color: "var(--status-ok)" }}
            >
              All caught up
            </span>
          )}
        </div>
      </div>
    </div>
  );
}
