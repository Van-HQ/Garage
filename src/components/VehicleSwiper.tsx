"use client";

import { useRef, useState } from "react";
import type { MaintenanceLog, MaintenanceType, MileageLog, Vehicle } from "@/lib/types";
import VehicleCard from "@/components/VehicleCard";

export default function VehicleSwiper({
  vehicles,
  types,
  logs,
  mileageLogs,
  onIndexChange,
}: {
  vehicles: Vehicle[];
  types: MaintenanceType[];
  logs: MaintenanceLog[];
  mileageLogs: MileageLog[];
  onIndexChange?: (index: number) => void;
}) {
  const trackRef = useRef<HTMLDivElement>(null);
  const [index, setIndex] = useState(0);

  function handleScroll() {
    const el = trackRef.current;
    if (!el) return;
    const i = Math.round(el.scrollLeft / el.clientWidth);
    if (i !== index) {
      setIndex(i);
      onIndexChange?.(i);
    }
  }

  function goTo(i: number) {
    const el = trackRef.current;
    if (!el) return;
    el.scrollTo({ left: i * el.clientWidth, behavior: "smooth" });
  }

  if (vehicles.length === 0) return null;

  return (
    <div className="flex flex-col gap-4">
      <div
        ref={trackRef}
        onScroll={handleScroll}
        className="flex overflow-x-auto snap-x snap-mandatory no-scrollbar -mx-1"
      >
        {vehicles.map((v) => (
          <VehicleCard key={v.id} vehicle={v} types={types} logs={logs} mileageLogs={mileageLogs} />
        ))}
      </div>

      {vehicles.length > 1 && (
        <div className="flex items-center justify-center gap-2">
          {vehicles.map((v, i) => (
            <button
              key={v.id}
              onClick={() => goTo(i)}
              aria-label={`Go to ${v.name}`}
              className="h-1.5 rounded-full transition-all"
              style={{
                width: i === index ? 20 : 6,
                background: i === index ? "var(--accent)" : "var(--muted)",
                opacity: i === index ? 1 : 0.35,
              }}
            />
          ))}
        </div>
      )}
    </div>
  );
}
