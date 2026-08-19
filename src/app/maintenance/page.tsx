"use client";

import { useEffect, useMemo, useState } from "react";
import { Loader2 } from "lucide-react";
import { useGarageData } from "@/lib/useGarageData";
import { computeMaintenanceStatus } from "@/lib/maintenance-status";
import StatusRow from "@/components/StatusRow";

export default function MaintenancePage() {
  const { vehicles, types, logs, loading } = useGarageData();
  const [vehicleId, setVehicleId] = useState("");

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- default selection once data loads
    if (!vehicleId && vehicles.length > 0) setVehicleId(vehicles[0].id);
  }, [vehicles, vehicleId]);

  const vehicle = useMemo(() => vehicles.find((v) => v.id === vehicleId), [vehicles, vehicleId]);

  const status = useMemo(() => {
    if (!vehicle) return [];
    return computeMaintenanceStatus(vehicle, types, logs);
  }, [vehicle, types, logs]);

  const history = useMemo(() => {
    if (!vehicle) return [];
    return logs.filter((l) => l.vehicle_id === vehicle.id).slice(0, 15);
  }, [vehicle, logs]);

  if (loading) {
    return (
      <main className="flex-1 flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-muted" />
      </main>
    );
  }

  if (vehicles.length === 0) {
    return (
      <main className="flex-1 flex items-center justify-center px-8 text-center text-sm text-muted">
        Add a vehicle in Settings to see maintenance status.
      </main>
    );
  }

  return (
    <main className="flex-1 px-5 pt-[max(1.5rem,env(safe-area-inset-top))] pb-40 flex flex-col gap-6">
      <div>
        <p className="text-xs font-medium tracking-[0.14em] uppercase text-muted">Upkeep</p>
        <h1 className="text-2xl font-semibold tracking-tight mt-0.5">Maintenance</h1>
      </div>

      {vehicles.length > 1 && (
        <div className="flex gap-2">
          {vehicles.map((v) => (
            <button
              key={v.id}
              onClick={() => setVehicleId(v.id)}
              className="flex-1 min-w-0 glass-panel rounded-2xl py-3 text-sm font-medium truncate"
              style={{
                color: v.id === vehicleId ? "var(--accent)" : "var(--foreground)",
                opacity: v.id === vehicleId ? 1 : 0.65,
              }}
            >
              {v.name}
            </button>
          ))}
        </div>
      )}

      <div className="flex flex-col gap-3">
        <h3 className="text-sm font-semibold text-muted px-1">Status</h3>
        <div className="flex flex-col gap-2.5">
          {status.length === 0 ? (
            <div className="glass-panel rounded-3xl px-4 py-6 text-center text-sm text-muted">
              No maintenance types set up yet. Add some in Settings.
            </div>
          ) : (
            status.map((item) => <StatusRow key={item.type.id} item={item} />)
          )}
        </div>
      </div>

      <div className="flex flex-col gap-3">
        <h3 className="text-sm font-semibold text-muted px-1">History</h3>
        <div className="flex flex-col gap-2.5">
          {history.length === 0 ? (
            <div className="glass-panel rounded-3xl px-4 py-6 text-center text-sm text-muted">
              No entries logged yet.
            </div>
          ) : (
            history.map((log) => (
              <div key={log.id} className="glass-panel rounded-3xl px-4 py-3.5 flex items-center gap-3.5">
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium truncate">{log.title}</p>
                  <p className="text-xs text-muted truncate">
                    {new Date(log.performed_at).toLocaleDateString(undefined, {
                      month: "short",
                      day: "numeric",
                      year: "numeric",
                    })}{" "}
                    · {log.mileage_at.toLocaleString()} mi
                    {log.cost ? ` · $${log.cost.toLocaleString()}` : ""}
                  </p>
                  {log.notes && <p className="text-xs text-muted mt-1 truncate">{log.notes}</p>}
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </main>
  );
}
