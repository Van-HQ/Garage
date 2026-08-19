"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { MaintenanceLog, MaintenanceType, MileageLog, Vehicle } from "@/lib/types";
import { DEMO_VEHICLES, DEMO_TYPES, DEMO_LOGS } from "@/lib/demo-data";

const DEMO_MODE = process.env.NEXT_PUBLIC_SUPABASE_URL?.includes("placeholder");

export function useGarageData() {
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [types, setTypes] = useState<MaintenanceType[]>([]);
  const [logs, setLogs] = useState<MaintenanceLog[]>([]);
  const [mileageLogs, setMileageLogs] = useState<MileageLog[]>([]);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    if (DEMO_MODE) {
      setVehicles(DEMO_VEHICLES);
      setTypes(DEMO_TYPES);
      setLogs(DEMO_LOGS);
      setMileageLogs([]);
      setLoading(false);
      return;
    }
    const supabase = createClient();
    const [{ data: v }, { data: t }, { data: l }, { data: m }] = await Promise.all([
      supabase.from("vehicles").select("*").order("sort_order", { ascending: true }),
      supabase.from("maintenance_types").select("*").order("created_at", { ascending: true }),
      supabase.from("maintenance_logs").select("*").order("performed_at", { ascending: false }),
      supabase.from("mileage_logs").select("*").order("recorded_at", { ascending: false }),
    ]);
    setVehicles(v ?? []);
    setTypes(t ?? []);
    setLogs(l ?? []);
    setMileageLogs(m ?? []);
    setLoading(false);
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- initial data fetch on mount
    refresh();
  }, [refresh]);

  return { vehicles, types, logs, mileageLogs, loading, refresh };
}
