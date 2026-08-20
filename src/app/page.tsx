"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { Plus, Loader2, CarFront } from "lucide-react";
import { useGarageData } from "@/lib/useGarageData";
import { computeMaintenanceStatus } from "@/lib/maintenance-status";
import VehicleSwiper from "@/components/VehicleSwiper";
import StatusRow from "@/components/StatusRow";

export default function HomePage() {
  const { vehicles, types, logs, loading } = useGarageData();
  const [index, setIndex] = useState(0);
  const vehicle = vehicles[index];

  const status = useMemo(() => {
    if (!vehicle) return [];
    return computeMaintenanceStatus(vehicle, types, logs).slice(0, 4);
  }, [vehicle, types, logs]);

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
    <main className="flex-1 px-5 pt-[calc(env(safe-area-inset-top)+1rem)] pb-40 flex flex-col gap-7">
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

      <VehicleSwiper vehicles={vehicles} types={types} logs={logs} onIndexChange={setIndex} />

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
    </main>
  );
}
