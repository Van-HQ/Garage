import type { MaintenanceLog, MileageLog, Vehicle } from "@/lib/types";

export type TrendPoint = { date: string; mileage: number; kind: "maintenance" | "checkin"; label?: string };

/** Chronological odometer readings for a vehicle, drawn from every logged source. */
export function computeMileageTrend(
  vehicle: Vehicle,
  logs: MaintenanceLog[],
  mileageLogs: MileageLog[]
): TrendPoint[] {
  const points: TrendPoint[] = [];

  for (const l of logs) {
    if (l.vehicle_id === vehicle.id) points.push({ date: l.performed_at, mileage: l.mileage_at, kind: "maintenance", label: l.title });
  }
  for (const m of mileageLogs) {
    if (m.vehicle_id === vehicle.id) points.push({ date: m.recorded_at, mileage: m.mileage, kind: "checkin" });
  }

  return points.sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());
}

export type MonthlyMiles = { label: string; fullLabel: string; miles: number };

/**
 * Miles driven per calendar month, derived by diffing the last known odometer
 * reading of each month against the last reading of the month before it.
 * Months with no reading at all are simply absent rather than estimated.
 */
export function computeMonthlyMiles(points: TrendPoint[], limit = 6): MonthlyMiles[] {
  if (points.length < 2) return [];

  const lastReadingByMonth = new Map<string, number>();
  for (const p of points) {
    const d = new Date(p.date);
    lastReadingByMonth.set(`${d.getFullYear()}-${d.getMonth()}`, p.mileage);
  }

  const months = Array.from(lastReadingByMonth.entries());
  const result: MonthlyMiles[] = [];

  for (let i = 1; i < months.length; i++) {
    const [key, mileage] = months[i];
    const [, prevMileage] = months[i - 1];
    const [year, month] = key.split("-").map(Number);
    const label = new Date(year, month, 1).toLocaleDateString(undefined, { month: "short" });
    const fullLabel = new Date(year, month, 1).toLocaleDateString(undefined, { month: "long", year: "numeric" });
    result.push({ label, fullLabel, miles: Math.max(0, mileage - prevMileage) });
  }

  return result.slice(-limit);
}
