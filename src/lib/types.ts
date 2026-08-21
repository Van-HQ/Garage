export type Vehicle = {
  id: string;
  user_id: string;
  name: string;
  make: string;
  model: string;
  year: number;
  color: string | null;
  icon: string;
  current_mileage: number;
  manual_uploaded_at: string | null;
  mileage_updated_at: string;
  avg_daily_miles: number;
  sort_order: number;
  created_at: string;
};

export type MaintenanceType = {
  id: string;
  user_id: string;
  vehicle_id: string | null;
  name: string;
  category: "oil" | "tires" | "wash" | "upgrade" | "inspection" | "custom";
  icon: string;
  interval_miles: number | null;
  interval_days: number | null;
  baseline_mileage: number | null;
  baseline_date: string | null;
  created_at: string;
};

export type MaintenanceLog = {
  id: string;
  user_id: string;
  vehicle_id: string;
  maintenance_type_id: string | null;
  title: string;
  notes: string;
  cost: number | null;
  mileage_at: number;
  performed_at: string;
  created_at: string;
};

export type MaintenancePhoto = {
  id: string;
  user_id: string;
  maintenance_log_id: string;
  storage_path: string;
  created_at: string;
};

export type MileageLog = {
  id: string;
  user_id: string;
  vehicle_id: string;
  mileage: number;
  note: string;
  recorded_at: string;
  created_at: string;
};

export const MAINTENANCE_CATEGORIES: { value: MaintenanceType["category"]; label: string; icon: string }[] = [
  { value: "oil", label: "Oil Change", icon: "droplet" },
  { value: "tires", label: "Tires", icon: "circle-dot" },
  { value: "wash", label: "Car Wash", icon: "sparkles" },
  { value: "upgrade", label: "Upgrade / Mod", icon: "wand-2" },
  { value: "inspection", label: "Inspection", icon: "clipboard-check" },
  { value: "custom", label: "Custom", icon: "wrench" },
];

export type MaintenancePreset = {
  name: string;
  category: MaintenanceType["category"];
  icon: string;
  interval_miles: number | null;
  interval_days: number | null;
};

/**
 * General-purpose intervals, not manufacturer-specific — a starting point to
 * edit or delete, not a substitute for the vehicle's actual owner's manual.
 */
export const MAINTENANCE_PRESETS: MaintenancePreset[] = [
  { name: "Oil Change", category: "oil", icon: "droplet", interval_miles: 5000, interval_days: 180 },
  { name: "Tire Rotation", category: "tires", icon: "circle-dot", interval_miles: 6000, interval_days: null },
  { name: "Cabin Air Filter", category: "custom", icon: "wrench", interval_miles: 15000, interval_days: 365 },
  { name: "Engine Air Filter", category: "custom", icon: "wrench", interval_miles: 15000, interval_days: null },
  { name: "Brake Fluid Flush", category: "inspection", icon: "clipboard-check", interval_miles: 30000, interval_days: 730 },
  { name: "Wheel Alignment", category: "inspection", icon: "clipboard-check", interval_miles: 12000, interval_days: null },
  { name: "Spark Plugs", category: "custom", icon: "wrench", interval_miles: 30000, interval_days: null },
  { name: "Transmission Fluid", category: "custom", icon: "wrench", interval_miles: 30000, interval_days: null },
  { name: "Battery Check", category: "inspection", icon: "clipboard-check", interval_miles: null, interval_days: 365 },
  { name: "Wiper Blades", category: "custom", icon: "wrench", interval_miles: null, interval_days: 365 },
];

/**
 * Derived directly from Toyota's official 2024 Tacoma Warranty & Maintenance
 * Guide (toyota.com/content/dam/toyota/brochures/pdf/2024/T-MMS-24Tacoma.pdf),
 * normal (non-severe) driving conditions. Toyota's real schedule is a
 * conditional checklist that varies item-by-item across visits — this is a
 * single-interval simplification of the items that had a clear, repeated
 * "replace at X miles" instruction in the source document. Items only
 * scheduled under towing/dirt-road/severe conditions (differential oil,
 * transfer case oil, propeller shaft re-torque, etc.) were intentionally
 * left out rather than guessed at.
 */
export const TACOMA_2024_PRESETS: MaintenancePreset[] = [
  { name: "Oil & Filter Change", category: "oil", icon: "droplet", interval_miles: 10000, interval_days: 365 },
  { name: "Tire Rotation", category: "tires", icon: "circle-dot", interval_miles: 5000, interval_days: 180 },
  { name: "Brake Inspection", category: "inspection", icon: "clipboard-check", interval_miles: 5000, interval_days: 180 },
  { name: "Cabin Air Filter", category: "custom", icon: "wrench", interval_miles: 30000, interval_days: null },
  { name: "Engine Air Filter", category: "custom", icon: "wrench", interval_miles: 30000, interval_days: null },
  { name: "Spark Plugs", category: "custom", icon: "wrench", interval_miles: 40000, interval_days: 1460 },
];
