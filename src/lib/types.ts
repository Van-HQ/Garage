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
