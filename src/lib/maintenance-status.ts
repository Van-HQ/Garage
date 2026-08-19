import type { MaintenanceLog, MaintenanceType, Vehicle } from "@/lib/types";

const DAY_MS = 1000 * 60 * 60 * 24;

/** Projects today's mileage forward from the last known odometer reading using the vehicle's average daily miles. */
export function projectedMileage(vehicle: Vehicle, now: Date = new Date()): number {
  const daysSince = Math.max(0, (now.getTime() - new Date(vehicle.mileage_updated_at).getTime()) / DAY_MS);
  return Math.round(vehicle.current_mileage + daysSince * vehicle.avg_daily_miles);
}

export type DueStatus = "overdue" | "due-soon" | "ok" | "unscheduled";

export type MaintenanceStatusItem = {
  type: MaintenanceType;
  lastLog: MaintenanceLog | null;
  dueMileage: number | null;
  dueDate: string | null;
  milesRemaining: number | null;
  daysRemaining: number | null;
  status: DueStatus;
};

/** "Due soon" triggers inside this many miles or days of the threshold. */
const SOON_MILES = 500;
const SOON_DAYS = 14;

export function computeMaintenanceStatus(
  vehicle: Vehicle,
  types: MaintenanceType[],
  logs: MaintenanceLog[],
  now: Date = new Date()
): MaintenanceStatusItem[] {
  const projMiles = projectedMileage(vehicle, now);

  return types
    .filter((t) => t.vehicle_id === null || t.vehicle_id === vehicle.id)
    .map((type) => {
      const typeLogs = logs
        .filter((l) => l.maintenance_type_id === type.id && l.vehicle_id === vehicle.id)
        .sort((a, b) => new Date(b.performed_at).getTime() - new Date(a.performed_at).getTime());
      const lastLog = typeLogs[0] ?? null;

      const baseMileage = lastLog ? lastLog.mileage_at : 0;
      const baseDate = lastLog ? new Date(lastLog.performed_at) : new Date(vehicle.created_at);

      const dueMileage = type.interval_miles != null ? baseMileage + type.interval_miles : null;
      const dueDate =
        type.interval_days != null
          ? new Date(baseDate.getTime() + type.interval_days * DAY_MS).toISOString()
          : null;

      const milesRemaining = dueMileage != null ? dueMileage - projMiles : null;
      const daysRemaining =
        dueDate != null ? Math.round((new Date(dueDate).getTime() - now.getTime()) / DAY_MS) : null;

      let status: DueStatus = "unscheduled";
      if (milesRemaining == null && daysRemaining == null) {
        status = lastLog ? "ok" : "unscheduled";
      } else {
        const overdue = (milesRemaining != null && milesRemaining <= 0) || (daysRemaining != null && daysRemaining <= 0);
        const soon =
          (milesRemaining != null && milesRemaining <= SOON_MILES) ||
          (daysRemaining != null && daysRemaining <= SOON_DAYS);
        status = overdue ? "overdue" : soon ? "due-soon" : "ok";
      }

      return { type, lastLog, dueMileage, dueDate, milesRemaining, daysRemaining, status };
    })
    .sort((a, b) => {
      const rank: Record<DueStatus, number> = { overdue: 0, "due-soon": 1, ok: 2, unscheduled: 3 };
      return rank[a.status] - rank[b.status];
    });
}
