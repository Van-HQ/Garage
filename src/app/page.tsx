"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { Plus, Loader2, CarFront, Droplet, CircleDot, Sparkles, Wand2, ClipboardCheck, Wrench } from "lucide-react";
import { useGarageData } from "@/lib/useGarageData";
import { computeMaintenanceStatus } from "@/lib/maintenance-status";
import { usePhotoUrls } from "@/lib/usePhotoUrls";
import VehicleSwiper from "@/components/VehicleSwiper";
import StatusRow from "@/components/StatusRow";

const ICONS: Record<string, typeof Wrench> = {
  droplet: Droplet,
  "circle-dot": CircleDot,
  sparkles: Sparkles,
  "wand-2": Wand2,
  "clipboard-check": ClipboardCheck,
  wrench: Wrench,
};

export default function HomePage() {
  const { vehicles, types, logs, mileageLogs, photos, loading } = useGarageData();
  const [index, setIndex] = useState(0);
  const vehicle = vehicles[index];
  const photoUrls = usePhotoUrls(photos);

  const status = useMemo(() => {
    if (!vehicle) return [];
    return computeMaintenanceStatus(vehicle, types, logs).slice(0, 4);
  }, [vehicle, types, logs]);

  const recent = useMemo(() => {
    if (!vehicle) return [];
    return logs.filter((l) => l.vehicle_id === vehicle.id).slice(0, 3);
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
      <main className="flex-1 flex flex-col items-center justify-center gap-4 px-8 text-center">
        <div className="glass-panel w-16 h-16 rounded-[22px] flex items-center justify-center">
          <CarFront className="w-8 h-8 text-accent" strokeWidth={1.5} />
        </div>
        <div>
          <h1 className="text-lg font-semibold">No vehicles yet</h1>
          <p className="text-sm text-muted mt-1">Add your Tacoma and RAV4 to get started</p>
        </div>
        <Link href="/settings" className="btn-accent rounded-2xl px-5 py-2.5 text-sm font-medium">
          Add a vehicle
        </Link>
      </main>
    );
  }

  return (
    <main className="flex-1 px-5 pt-[calc(env(safe-area-inset-top)+1.75rem)] pb-40 flex flex-col gap-7">
      <div className="flex items-center justify-between">
        <p className="text-sm font-semibold text-muted">My Garage</p>
        <Link
          href="/log"
          className="glass-panel w-9 h-9 rounded-full flex items-center justify-center text-foreground"
          aria-label="Log entry"
        >
          <Plus className="w-4 h-4" strokeWidth={2.3} />
        </Link>
      </div>

      <VehicleSwiper vehicles={vehicles} types={types} logs={logs} mileageLogs={mileageLogs} onIndexChange={setIndex} />

      {vehicle && (
        <div className="flex flex-col gap-3">
          <div className="flex items-center justify-between px-1">
            <h3 className="text-sm font-semibold text-muted">Maintenance</h3>
            <Link href="/maintenance" className="text-sm font-medium text-accent">
              View all
            </Link>
          </div>
          {status.length === 0 ? (
            <div className="glass-panel rounded-3xl px-4 py-6 text-center text-sm text-muted">
              No maintenance items yet. Add some in Settings.
            </div>
          ) : (
            <div className="list-panel">
              {status.map((item) => (
                <StatusRow key={item.type.id} item={item} vehicleId={vehicle.id} />
              ))}
            </div>
          )}
        </div>
      )}

      {vehicle && recent.length > 0 && (
        <div className="flex flex-col gap-3">
          <div className="flex items-center justify-between px-1">
            <h3 className="text-sm font-semibold text-muted">Recent Activity</h3>
            <Link href="/maintenance" className="text-sm font-medium text-accent">
              View all
            </Link>
          </div>
          <div className="list-panel">
            {recent.map((log) => {
              const type = types.find((t) => t.id === log.maintenance_type_id);
              const Icon = ICONS[type?.icon ?? "wrench"] ?? Wrench;
              const photo = photos.find((p) => p.maintenance_log_id === log.id);
              const thumbUrl = photo ? photoUrls[photo.storage_path] : undefined;

              return (
                <div key={log.id} className="list-row">
                  <div
                    className="w-7 h-7 rounded-lg flex items-center justify-center shrink-0"
                    style={{ background: "color-mix(in srgb, var(--status-ok) 15%, transparent)", color: "var(--status-ok)" }}
                  >
                    <Icon className="w-3.5 h-3.5" strokeWidth={2} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-[15px] font-medium truncate">{log.title}</p>
                    <p className="text-xs text-muted truncate">
                      {new Date(log.performed_at).toLocaleDateString(undefined, { month: "short", day: "numeric" })} ·{" "}
                      {log.mileage_at.toLocaleString()} mi
                      {log.cost ? ` · $${log.cost.toLocaleString()}` : ""}
                    </p>
                  </div>
                  {thumbUrl && (
                    /* eslint-disable-next-line @next/next/no-img-element */
                    <img src={thumbUrl} alt="" className="w-9 h-9 rounded-lg object-cover shrink-0" />
                  )}
                </div>
              );
            })}
          </div>
        </div>
      )}
    </main>
  );
}
