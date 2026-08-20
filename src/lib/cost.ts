import type { MaintenanceLog, MaintenanceType } from "@/lib/types";
import { MAINTENANCE_CATEGORIES } from "@/lib/types";

export type CostBreakdown = {
  total: number;
  thisYearTotal: number;
  byCategory: { category: string; label: string; amount: number }[];
};

export function computeCostBreakdown(
  vehicleId: string,
  logs: MaintenanceLog[],
  types: MaintenanceType[],
  now: Date = new Date()
): CostBreakdown {
  const vehicleLogs = logs.filter((l) => l.vehicle_id === vehicleId && l.cost != null);
  const typeById = new Map(types.map((t) => [t.id, t]));
  const currentYear = now.getFullYear();

  let total = 0;
  let thisYearTotal = 0;
  const byCategoryMap = new Map<string, number>();

  for (const log of vehicleLogs) {
    const amount = log.cost ?? 0;
    total += amount;
    if (new Date(log.performed_at).getFullYear() === currentYear) thisYearTotal += amount;

    const category = typeById.get(log.maintenance_type_id ?? "")?.category ?? "custom";
    byCategoryMap.set(category, (byCategoryMap.get(category) ?? 0) + amount);
  }

  const byCategory = Array.from(byCategoryMap.entries())
    .map(([category, amount]) => ({
      category,
      label: MAINTENANCE_CATEGORIES.find((c) => c.value === category)?.label ?? "Other",
      amount,
    }))
    .sort((a, b) => b.amount - a.amount);

  return { total, thisYearTotal, byCategory };
}
