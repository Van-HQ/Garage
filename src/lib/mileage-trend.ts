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
 * Miles driven per calendar month. Each stretch between two consecutive
 * readings is credited to the month its midpoint falls in, so a reading taken
 * on Aug 1 closes out July rather than starting August (and one taken Jul 31
 * still counts for July). Months with no stretch landing in them are simply
 * absent rather than estimated.
 */
export function computeMonthlyMiles(points: TrendPoint[], limit = 6): MonthlyMiles[] {
  if (points.length < 2) return [];

  // Points are chronological, so midpoints are too and Map order is month order.
  const milesByMonth = new Map<string, number>();
  for (let i = 1; i < points.length; i++) {
    const from = points[i - 1];
    const to = points[i];
    const mid = new Date((new Date(from.date).getTime() + new Date(to.date).getTime()) / 2);
    const key = `${mid.getFullYear()}-${mid.getMonth()}`;
    milesByMonth.set(key, (milesByMonth.get(key) ?? 0) + Math.max(0, to.mileage - from.mileage));
  }

  const result: MonthlyMiles[] = [];
  for (const [key, miles] of milesByMonth) {
    const [year, month] = key.split("-").map(Number);
    const label = new Date(year, month, 1).toLocaleDateString(undefined, { month: "short" });
    const fullLabel = new Date(year, month, 1).toLocaleDateString(undefined, { month: "long", year: "numeric" });
    result.push({ label, fullLabel, miles });
  }

  return result.slice(-limit);
}

export type MonthlyStat = MonthlyMiles & {
  /** Miles driven minus the previous month's miles; null for the first month on record. */
  changeMiles: number | null;
  /** changeMiles as a % of the previous month's miles; null when there is no (or a zero) previous month. */
  changePct: number | null;
};

/** Monthly miles with month-over-month change, newest month first. */
export function computeMonthlyStats(points: TrendPoint[], limit = 6): MonthlyStat[] {
  const all = computeMonthlyMiles(points, Number.MAX_SAFE_INTEGER);
  return all
    .map((m, i): MonthlyStat => {
      const prev = all[i - 1];
      if (!prev) return { ...m, changeMiles: null, changePct: null };
      return {
        ...m,
        changeMiles: m.miles - prev.miles,
        changePct: prev.miles > 0 ? Math.round(((m.miles - prev.miles) / prev.miles) * 100) : null,
      };
    })
    .slice(-limit)
    .reverse();
}
