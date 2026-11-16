// Generates the golden fixture GarageCore's tests check against, by running the
// web app's real src/lib functions on a fixed data set. Re-run after changing
// anything in src/lib that the iOS app ports:
//
//   TZ=America/Los_Angeles node ios/tools/gen-core-golden.mjs
//
// (Month bucketing uses local time, so the time zone is pinned; the Swift tests
// use the same zone.)
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { computeMaintenanceStatus, projectedMileage } from "../../src/lib/maintenance-status.ts";
import { computeMileageTrend, computeMonthlyMiles, computeMonthlyStats } from "../../src/lib/mileage-trend.ts";
import { historyForType, computeIntervalAverage, totalCost } from "../../src/lib/care-detail.ts";

if (process.env.TZ !== "America/Los_Angeles") {
  throw new Error("Run with TZ=America/Los_Angeles so month boundaries match the Swift tests.");
}

const U = "00000000-0000-4000-8000-0000000000aa";
const id = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
const now = "2026-11-15T20:30:00.000Z";

const vehicles = [
  { id: id(1), user_id: U, name: "Buddy", make: "Toyota", model: "Tacoma TRD Sport", year: 2024, color: "#e6d3c1", icon: "truck",
    current_mileage: 11400, manual_uploaded_at: "2026-08-20T18:00:00.000Z", mileage_updated_at: "2026-11-01T19:00:00.000Z",
    avg_daily_miles: 31.5, sort_order: 0, created_at: "2025-10-14T19:00:00.000Z" },
  { id: id(2), user_id: U, name: "RAV4", make: "Toyota", model: "RAV4 XLE", year: 2022, color: null, icon: "car",
    current_mileage: 41230, manual_uploaded_at: null, mileage_updated_at: "2026-11-20T19:00:00.000Z", // in the future: clamps to 0 days
    avg_daily_miles: 22, sort_order: 1, created_at: "2024-03-02T19:00:00.000Z" },
];

const type = (n, o) => ({ id: id(n), user_id: U, vehicle_id: null, category: "custom", icon: "wrench",
  interval_miles: null, interval_days: null, baseline_mileage: null, baseline_date: null, created_at: "2025-10-14T19:00:00.000Z", ...o });
const types = [
  type(10, { name: "Oil & Filter Change", category: "oil", icon: "droplet", interval_miles: 10000, interval_days: 365 }),
  type(11, { name: "Tire Rotation", category: "tires", icon: "circle-dot", interval_miles: 5000, interval_days: 180 }),
  type(12, { name: "Car Wash", category: "wash", icon: "sparkles", interval_days: 14 }),
  type(13, { name: "Battery Check", category: "inspection", vehicle_id: id(1), interval_days: 365, baseline_mileage: 0, baseline_date: "2025-10-14T19:00:00.000Z" }),
  type(14, { name: "Lift Kit", category: "upgrade", vehicle_id: id(1) }), // no interval, logged once
  type(15, { name: "Wiper Blades" }), // no interval, never logged
  type(16, { name: "Cabin Air Filter", interval_miles: 12000, baseline_mileage: 0 }), // due soon on mileage for Buddy
  type(17, { name: "RAV4 Brake Fluid", vehicle_id: id(2), interval_miles: 30000, interval_days: 730 }),
  type(18, { name: "Half-day Check", vehicle_id: id(1), interval_days: 30 }), // lands on a .5 day boundary
];

const log = (n, vehicle, typeId, title, mileage_at, performed_at, cost = null, notes = "") => ({
  id: id(n), user_id: U, vehicle_id: id(vehicle), maintenance_type_id: typeId ? id(typeId) : null,
  title, notes, cost, mileage_at, performed_at, created_at: performed_at });
const logs = [
  log(100, 1, 10, "Oil & Filter Change", 4980, "2026-03-07T20:00:00.000Z", 74.5, "Dealer"),
  log(101, 1, 10, "Oil & Filter Change", 9950, "2026-09-12T19:00:00.000Z", 82),
  log(102, 1, 10, "Oil & Filter Change", 120, "2025-10-20T19:00:00.000Z", 0),
  log(103, 1, 11, "Tire Rotation", 5100, "2026-03-15T19:00:00.000Z", 25),
  log(104, 1, 12, "Car Wash", 11200, "2026-10-25T19:00:00.000Z", 18),
  log(105, 1, 12, "Car Wash", 11380, "2026-11-01T19:00:00.000Z", null),
  log(106, 1, 14, "Lift Kit", 8000, "2026-07-04T19:00:00.000Z", 1899.99, "2 inch"),
  log(107, 1, null, "Windshield chip repair", 8700, "2026-08-01T06:30:00.000Z", 60),
  log(108, 2, 10, "Oil & Filter Change", 38000, "2026-04-09T19:00:00.000Z", 65),
  log(109, 2, 12, "Car Wash", 41000, "2026-10-26T19:00:00.000Z", 20),
  log(110, 2, 17, "RAV4 Brake Fluid", 21000, "2024-11-16T08:30:00.000Z", 140),
  log(111, 1, 18, "Half-day Check", 10800, "2026-10-31T08:30:00.000Z", null),
];

const reading = (n, vehicle, mileage, recorded_at, note = "") => ({
  id: id(n), user_id: U, vehicle_id: id(vehicle), mileage, note, recorded_at, created_at: recorded_at });
const mileageLogs = [
  reading(200, 1, 0, "2025-10-14T19:00:00.000Z", "Purchase"),
  reading(201, 1, 6900, "2026-05-31T19:00:00.000Z"),
  reading(202, 1, 7400, "2026-06-30T19:00:00.000Z"),
  reading(203, 1, 8650, "2026-07-31T23:00:00.000Z"),
  reading(204, 1, 9400, "2026-08-31T19:00:00.000Z"),
  reading(205, 1, 9390, "2026-09-01T19:00:00.000Z", "typo, lower than the last one"),
  reading(206, 1, 11400, "2026-11-01T19:00:00.000Z"),
  reading(207, 2, 39500, "2026-07-01T19:00:00.000Z"),
  reading(208, 2, 41230, "2026-11-20T19:00:00.000Z"),
];

const nowDate = new Date(now);
const monthName = (m) => m.fullLabel;
const expected = {};
for (const v of vehicles) {
  const trend = computeMileageTrend(v, logs, mileageLogs);
  expected[v.id] = {
    projectedMileage: projectedMileage(v, nowDate),
    status: computeMaintenanceStatus(v, types, logs, nowDate).map((s) => ({
      typeId: s.type.id, lastLogId: s.lastLog?.id ?? null, dueMileage: s.dueMileage, dueDate: s.dueDate,
      milesRemaining: s.milesRemaining, daysRemaining: s.daysRemaining, status: s.status,
    })),
    trend: trend.map((p) => ({ date: p.date, mileage: p.mileage, kind: p.kind, label: p.label ?? null })),
    monthlyMiles: computeMonthlyMiles(trend).map((m) => ({ fullLabel: monthName(m), miles: m.miles })),
    monthlyMilesAll: computeMonthlyMiles(trend, 1000).map((m) => ({ fullLabel: monthName(m), miles: m.miles })),
    monthlyStats: computeMonthlyStats(trend).map((m) => ({ fullLabel: monthName(m), miles: m.miles, changeMiles: m.changeMiles, changePct: m.changePct })),
    careDetail: types.map((t) => {
      const history = historyForType(logs, v, t);
      return { typeId: t.id, historyIds: history.map((l) => l.id), average: computeIntervalAverage(history, t), totalCost: totalCost(history) };
    }),
  };
}

const out = fileURLToPath(new URL("../Packages/GarageCore/Tests/GarageCoreTests/Fixtures/golden.json", import.meta.url));
writeFileSync(out, JSON.stringify({ now, vehicles, types, logs, mileageLogs, expected }, null, 2) + "\n");
console.log("wrote", out);
