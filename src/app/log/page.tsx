"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2, CheckCircle2, Gauge, Wrench, Camera, X } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { useGarageData } from "@/lib/useGarageData";
import { projectedMileage } from "@/lib/maintenance-status";

type Mode = "maintenance" | "mileage";

type PendingPhoto = { file: File; previewUrl: string };

export default function LogPage() {
  const router = useRouter();
  const { vehicles, types, loading, refresh } = useGarageData();
  const [mode, setMode] = useState<Mode>("maintenance");
  const [vehicleId, setVehicleId] = useState("");
  const [typeId, setTypeId] = useState("");
  const [mileage, setMileage] = useState("");
  const [notes, setNotes] = useState("");
  const [cost, setCost] = useState("");
  const [date, setDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [photos, setPhotos] = useState<PendingPhoto[]>([]);
  const photoInputRef = useRef<HTMLInputElement>(null);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- default selection once data loads
    if (!vehicleId && vehicles.length > 0) setVehicleId(vehicles[0].id);
  }, [vehicles, vehicleId]);

  const vehicle = useMemo(() => vehicles.find((v) => v.id === vehicleId), [vehicles, vehicleId]);
  const vehicleTypes = useMemo(
    () => types.filter((t) => t.vehicle_id === null || t.vehicle_id === vehicleId),
    [types, vehicleId]
  );

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- seed mileage once vehicle loads, not on every keystroke
    if (vehicle && !mileage) setMileage(String(projectedMileage(vehicle)));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [vehicle]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- default selection once types load
    if (!typeId && vehicleTypes.length > 0) setTypeId(vehicleTypes[0].id);
  }, [vehicleTypes, typeId]);

  function addPhotos(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files ?? []);
    e.target.value = "";
    setPhotos((prev) => [...prev, ...files.map((file) => ({ file, previewUrl: URL.createObjectURL(file) }))]);
  }

  function removePhoto(index: number) {
    setPhotos((prev) => {
      URL.revokeObjectURL(prev[index].previewUrl);
      return prev.filter((_, i) => i !== index);
    });
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!vehicle) return;
    setSaving(true);
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;

    const performedAt = new Date(date + "T12:00:00").toISOString();

    if (mode === "maintenance") {
      const type = vehicleTypes.find((t) => t.id === typeId);
      const { data: inserted } = await supabase
        .from("maintenance_logs")
        .insert({
          user_id: user.id,
          vehicle_id: vehicle.id,
          maintenance_type_id: typeId || null,
          title: type?.name ?? "Maintenance",
          notes,
          cost: cost ? Number(cost) : null,
          mileage_at: Number(mileage),
          performed_at: performedAt,
        })
        .select()
        .single();

      if (inserted && photos.length > 0) {
        for (const photo of photos) {
          const ext = photo.file.name.split(".").pop() || "jpg";
          const path = `${user.id}/${inserted.id}/${crypto.randomUUID()}.${ext}`;
          const { error: uploadError } = await supabase.storage
            .from("maintenance-photos")
            .upload(path, photo.file, { contentType: photo.file.type || "image/jpeg" });
          if (!uploadError) {
            await supabase.from("maintenance_photos").insert({
              user_id: user.id,
              maintenance_log_id: inserted.id,
              storage_path: path,
            });
          }
        }
        photos.forEach((p) => URL.revokeObjectURL(p.previewUrl));
      }
    } else {
      await supabase.from("mileage_logs").insert({
        user_id: user.id,
        vehicle_id: vehicle.id,
        mileage: Number(mileage),
        note: notes,
        recorded_at: performedAt,
      });
    }

    await refresh();
    setSaving(false);
    setSaved(true);
    setNotes("");
    setCost("");
    setPhotos([]);
    setTimeout(() => setSaved(false), 1800);
  }

  if (loading) {
    return (
      <main className="flex-1 flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-muted" />
      </main>
    );
  }

  if (vehicles.length === 0) {
    return (
      <main className="flex-1 flex flex-col items-center justify-center gap-3 px-8 text-center">
        <p className="text-sm text-muted">Add a vehicle in Settings before logging entries.</p>
        <button onClick={() => router.push("/settings")} className="btn-accent rounded-2xl px-5 py-2.5 text-sm font-medium">
          Go to Settings
        </button>
      </main>
    );
  }

  return (
    <main className="flex-1 px-5 pt-[max(1.5rem,env(safe-area-inset-top))] pb-40 flex flex-col gap-6">
      <div>
        <p className="text-xs font-medium tracking-[0.14em] uppercase text-muted">New Entry</p>
        <h1 className="text-2xl font-semibold tracking-tight mt-0.5">Log</h1>
      </div>

      {/* Vehicle selector */}
      <div className="flex gap-2">
        {vehicles.map((v) => (
          <button
            key={v.id}
            onClick={() => setVehicleId(v.id)}
            className="flex-1 min-w-0 glass-panel rounded-2xl py-3 text-sm font-medium transition-all truncate"
            style={{
              borderColor: v.id === vehicleId ? "var(--accent)" : undefined,
              color: v.id === vehicleId ? "var(--accent)" : "var(--foreground)",
              opacity: v.id === vehicleId ? 1 : 0.65,
            }}
          >
            {v.name}
          </button>
        ))}
      </div>

      {/* Mode toggle */}
      <div className="glass-panel rounded-2xl p-1 flex gap-1">
        {[
          { key: "maintenance" as Mode, label: "Maintenance", icon: Wrench },
          { key: "mileage" as Mode, label: "Mileage only", icon: Gauge },
        ].map(({ key, label, icon: Icon }) => (
          <button
            key={key}
            onClick={() => setMode(key)}
            className="flex-1 min-w-0 flex items-center justify-center gap-1.5 rounded-xl py-2.5 text-sm font-medium transition-all"
            style={{
              background: mode === key ? "var(--accent)" : "transparent",
              color: mode === key ? "var(--accent-foreground)" : "var(--muted)",
            }}
          >
            <Icon className="w-4 h-4" strokeWidth={1.75} />
            {label}
          </button>
        ))}
      </div>

      <form onSubmit={submit} className="flex flex-col gap-4">
        {mode === "maintenance" && (
          <label className="flex flex-col gap-2">
            <span className="text-xs font-medium text-muted uppercase tracking-wide">Type</span>
            <select
              value={typeId}
              onChange={(e) => setTypeId(e.target.value)}
              className="glass-input w-full min-w-0 rounded-2xl px-4 py-3 text-sm outline-none"
            >
              {vehicleTypes.length === 0 && <option value="">No types yet — add in Settings</option>}
              {vehicleTypes.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                </option>
              ))}
            </select>
          </label>
        )}

        <label className="flex flex-col gap-2">
          <span className="text-xs font-medium text-muted uppercase tracking-wide">Odometer (mi)</span>
          <input
            type="number"
            required
            inputMode="numeric"
            value={mileage}
            onChange={(e) => setMileage(e.target.value)}
            className="glass-input w-full min-w-0 rounded-2xl px-4 py-3 text-sm outline-none"
          />
        </label>

        <label className="flex flex-col gap-2">
          <span className="text-xs font-medium text-muted uppercase tracking-wide">Date</span>
          <input
            type="date"
            required
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="glass-input w-full min-w-0 rounded-2xl px-4 py-3 text-sm outline-none"
          />
        </label>

        {mode === "maintenance" && (
          <label className="flex flex-col gap-2">
            <span className="text-xs font-medium text-muted uppercase tracking-wide">Cost ($, optional)</span>
            <input
              type="number"
              inputMode="decimal"
              value={cost}
              onChange={(e) => setCost(e.target.value)}
              className="glass-input w-full min-w-0 rounded-2xl px-4 py-3 text-sm outline-none"
            />
          </label>
        )}

        <label className="flex flex-col gap-2">
          <span className="text-xs font-medium text-muted uppercase tracking-wide">Notes</span>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={3}
            placeholder="Synthetic 5W-30, rotated tires too..."
            className="glass-input w-full min-w-0 rounded-2xl px-4 py-3 text-sm outline-none resize-none"
          />
        </label>

        {mode === "maintenance" && (
          <div className="flex flex-col gap-2">
            <span className="text-xs font-medium text-muted uppercase tracking-wide">Photos (optional)</span>
            <input
              ref={photoInputRef}
              type="file"
              accept="image/*"
              multiple
              className="hidden"
              onChange={addPhotos}
            />
            <div className="flex flex-wrap gap-2.5">
              {photos.map((p, i) => (
                <div key={p.previewUrl} className="relative w-16 h-16 shrink-0">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={p.previewUrl} alt="" className="w-full h-full object-cover rounded-xl" />
                  <button
                    type="button"
                    onClick={() => removePhoto(i)}
                    className="absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-black/70 flex items-center justify-center text-white"
                    aria-label="Remove photo"
                  >
                    <X className="w-3 h-3" />
                  </button>
                </div>
              ))}
              <button
                type="button"
                onClick={() => photoInputRef.current?.click()}
                className="glass-input w-16 h-16 shrink-0 rounded-xl flex items-center justify-center text-muted"
                aria-label="Add photo"
              >
                <Camera className="w-5 h-5" />
              </button>
            </div>
          </div>
        )}

        <button
          type="submit"
          disabled={saving || !vehicle}
          className="btn-accent rounded-2xl py-3.5 text-sm font-medium flex items-center justify-center gap-2 disabled:opacity-60 mt-1"
        >
          {saving ? (
            <Loader2 className="w-4 h-4 animate-spin" />
          ) : saved ? (
            <CheckCircle2 className="w-4 h-4" />
          ) : null}
          {saved ? "Saved" : "Save entry"}
        </button>
      </form>
    </main>
  );
}
