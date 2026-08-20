import type { MaintenanceLog, MileageLog, Vehicle } from "@/lib/types";

export type TrendPoint = { date: string; mileage: number };

/** Chronological odometer readings for a vehicle, drawn from every logged source. */
export function computeMileageTrend(
  vehicle: Vehicle,
  logs: MaintenanceLog[],
  mileageLogs: MileageLog[]
): TrendPoint[] {
  const points: TrendPoint[] = [];

  for (const l of logs) {
    if (l.vehicle_id === vehicle.id) points.push({ date: l.performed_at, mileage: l.mileage_at });
  }
  for (const m of mileageLogs) {
    if (m.vehicle_id === vehicle.id) points.push({ date: m.recorded_at, mileage: m.mileage });
  }

  return points.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
}
