"use client";

import { useEffect, useMemo, useState } from "react";
import { Loader2, Trash2 } from "lucide-react";
import { useGarageData } from "@/lib/useGarageData";
import { computeMaintenanceStatus } from "@/lib/maintenance-status";
import { computeCostBreakdown } from "@/lib/cost";
import { createClient } from "@/lib/supabase/client";
import StatusRow from "@/components/StatusRow";
import CostBreakdown from "@/components/CostBreakdown";

export default function MaintenancePage() {
  const { vehicles, types, logs, photos, loading, refresh } = useGarageData();
  const [vehicleId, setVehicleId] = useState("");
  const [photoUrls, setPhotoUrls] = useState<Record<string, string>>({});

  async function deleteLog(id: string) {
    const supabase = createClient();
    await supabase.from("maintenance_logs").delete().eq("id", id);
    await refresh();
  }

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- default selection once data loads
    if (!vehicleId && vehicles.length > 0) setVehicleId(vehicles[0].id);
  }, [vehicles, vehicleId]);

  useEffect(() => {
    if (photos.length === 0) return;
    let cancelled = false;
    const supabase = createClient();
    supabase.storage
      .from("maintenance-photos")
      .createSignedUrls(
        photos.map((p) => p.storage_path),
        3600
      )
      .then(({ data }) => {
        if (cancelled || !data) return;
        const map: Record<string, string> = {};
        data.forEach((d, i) => {
          if (d.signedUrl) map[photos[i].storage_path] = d.signedUrl;
        });
        setPhotoUrls(map);
      });
    return () => {
      cancelled = true;
    };
  }, [photos]);

  const vehicle = useMemo(() => vehicles.find((v) => v.id === vehicleId), [vehicles, vehicleId]);

  const status = useMemo(() => {
    if (!vehicle) return [];
    return computeMaintenanceStatus(vehicle, types, logs);
  }, [vehicle, types, logs]);

  const history = useMemo(() => {
    if (!vehicle) return [];
    return logs.filter((l) => l.vehicle_id === vehicle.id).slice(0, 15);
  }, [vehicle, logs]);

  const cost = useMemo(() => {
    if (!vehicle) return null;
    return computeCostBreakdown(vehicle.id, logs, types);
  }, [vehicle, logs, types]);

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
            status.map((item) => vehicle && <StatusRow key={item.type.id} item={item} vehicleId={vehicle.id} />)
          )}
        </div>
      </div>

      {cost && cost.total > 0 && (
        <div className="flex flex-col gap-3">
          <h3 className="text-sm font-semibold text-muted px-1">Spending</h3>
          <CostBreakdown data={cost} />
        </div>
      )}

      <div className="flex flex-col gap-3">
        <h3 className="text-sm font-semibold text-muted px-1">History</h3>
        <div className="flex flex-col gap-2.5">
          {history.length === 0 ? (
            <div className="glass-panel rounded-3xl px-4 py-6 text-center text-sm text-muted">
              No entries logged yet.
            </div>
          ) : (
            history.map((log) => {
              const logPhotos = photos.filter((p) => p.maintenance_log_id === log.id);
              return (
                <div key={log.id} className="glass-panel rounded-3xl px-4 py-3.5 flex flex-col gap-2.5">
                  <div className="flex items-center gap-3.5">
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
                    <button onClick={() => deleteLog(log.id)} className="text-muted p-2 shrink-0" aria-label="Delete entry">
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                  {logPhotos.length > 0 && (
                    <div className="flex gap-2 overflow-x-auto no-scrollbar -mx-1 px-1">
                      {logPhotos.map((p) => {
                        const url = photoUrls[p.storage_path];
                        if (!url) return null;
                        return (
                          <a key={p.id} href={url} target="_blank" rel="noreferrer" className="shrink-0">
                            {/* eslint-disable-next-line @next/next/no-img-element */}
                            <img src={url} alt="" className="w-16 h-16 object-cover rounded-xl" />
                          </a>
                        );
                      })}
                    </div>
                  )}
                </div>
              );
            })
          )}
        </div>
      </div>
    </main>
  );
}
