import type { MaintenanceLog, MaintenanceType, Vehicle } from "@/lib/types";

export function historyForType(logs: MaintenanceLog[], vehicle: Vehicle, type: MaintenanceType): MaintenanceLog[] {
  return logs
    .filter((l) => l.vehicle_id === vehicle.id && l.maintenance_type_id === type.id)
    .sort((a, b) => new Date(b.performed_at).getTime() - new Date(a.performed_at).getTime());
}

export type IntervalAverage = {
  avgMiles: number | null;
  avgDays: number | null;
  /** Positive = servicing more often than the target interval (ahead of schedule). */
  percentAheadMiles: number | null;
};

/** Average gap between consecutive logs of this type, oldest to newest. Needs at least 2 logs. */
export function computeIntervalAverage(history: MaintenanceLog[], type: MaintenanceType): IntervalAverage {
  if (history.length < 2) return { avgMiles: null, avgDays: null, percentAheadMiles: null };

  const chronological = [...history].sort((a, b) => new Date(a.performed_at).getTime() - new Date(b.performed_at).getTime());
  const first = chronological[0];
  const last = chronological[chronological.length - 1];
  const gaps = chronological.length - 1;

  const avgMiles = (last.mileage_at - first.mileage_at) / gaps;
  const avgDays = (new Date(last.performed_at).getTime() - new Date(first.performed_at).getTime()) / gaps / (1000 * 60 * 60 * 24);

  const percentAheadMiles =
    type.interval_miles != null && type.interval_miles > 0 ? Math.round(((type.interval_miles - avgMiles) / type.interval_miles) * 100) : null;

  return { avgMiles: Math.round(avgMiles), avgDays: Math.round(avgDays), percentAheadMiles };
}

export function totalCost(history: MaintenanceLog[]): number {
  return history.reduce((sum, l) => sum + (l.cost ?? 0), 0);
}
