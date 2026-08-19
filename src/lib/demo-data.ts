// Preview-only fixtures shown when NEXT_PUBLIC_SUPABASE_URL is still a placeholder,
// so the app is browsable before a real Supabase project is wired up.
import type { MaintenanceLog, MaintenanceType, Vehicle } from "@/lib/types";

const now = new Date();
const daysAgo = (n: number) => new Date(now.getTime() - n * 86400000).toISOString();

export const DEMO_VEHICLES: Vehicle[] = [
  {
    id: "v1",
    user_id: "u1",
    name: "Tacoma",
    make: "Toyota",
    model: "Tacoma TRD Off-Road",
    year: 2024,
    color: "#e6d3c1",
    icon: "truck",
    current_mileage: 18420,
    mileage_updated_at: daysAgo(3),
    avg_daily_miles: 32,
    sort_order: 0,
    created_at: daysAgo(240),
  },
  {
    id: "v2",
    user_id: "u1",
    name: "RAV4",
    make: "Toyota",
    model: "RAV4 XLE",
    year: 2022,
    color: "#0a84ff",
    icon: "car",
    current_mileage: 41230,
    mileage_updated_at: daysAgo(10),
    avg_daily_miles: 22,
    sort_order: 1,
    created_at: daysAgo(600),
  },
];

export const DEMO_TYPES: MaintenanceType[] = [
  { id: "t1", user_id: "u1", vehicle_id: null, name: "Oil Change", category: "oil", icon: "droplet", interval_miles: 5000, interval_days: 180, created_at: daysAgo(240) },
  { id: "t2", user_id: "u1", vehicle_id: null, name: "Tire Rotation", category: "tires", icon: "circle-dot", interval_miles: 6000, interval_days: null, created_at: daysAgo(240) },
  { id: "t3", user_id: "u1", vehicle_id: null, name: "Car Wash", category: "wash", icon: "sparkles", interval_miles: null, interval_days: 14, created_at: daysAgo(240) },
  { id: "t4", user_id: "u1", vehicle_id: "v1", name: "Off-Road Suspension Check", category: "custom", icon: "wrench", interval_miles: 10000, interval_days: null, created_at: daysAgo(240) },
];

export const DEMO_LOGS: MaintenanceLog[] = [
  { id: "l1", user_id: "u1", vehicle_id: "v1", maintenance_type_id: "t1", title: "Oil Change", notes: "Synthetic 5W-30", cost: 78, mileage_at: 13200, performed_at: daysAgo(200) },
  { id: "l2", user_id: "u1", vehicle_id: "v1", maintenance_type_id: "t2", title: "Tire Rotation", notes: "", cost: null, mileage_at: 15800, performed_at: daysAgo(90) },
  { id: "l3", user_id: "u1", vehicle_id: "v1", maintenance_type_id: "t3", title: "Car Wash", notes: "Hand wash + wax", cost: 25, mileage_at: 18100, performed_at: daysAgo(9) },
  { id: "l4", user_id: "u1", vehicle_id: "v2", maintenance_type_id: "t1", title: "Oil Change", notes: "", cost: 65, mileage_at: 38000, performed_at: daysAgo(220) },
  { id: "l5", user_id: "u1", vehicle_id: "v2", maintenance_type_id: "t3", title: "Car Wash", notes: "", cost: 20, mileage_at: 41000, performed_at: daysAgo(20) },
].map((l) => ({ ...l, created_at: l.performed_at }));
