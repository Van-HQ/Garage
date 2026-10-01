"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2, Plus, Trash2, Pencil, Gauge, Car, Truck, LogOut, X, FileText, Upload, ChevronUp, ChevronDown } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { useGarageData } from "@/lib/useGarageData";
import { MAINTENANCE_CATEGORIES, MAINTENANCE_PRESETS, TACOMA_2024_PRESETS, type MaintenancePreset, type MaintenanceType, type Vehicle } from "@/lib/types";

const ICON_OPTIONS: { value: string; icon: typeof Car }[] = [
  { value: "truck", icon: Truck },
  { value: "car", icon: Car },
];

const ACCENT_OPTIONS = ["#e6d3c1", "#ff6a3d", "#0a84ff", "#34c759", "#af52de", "#ff375f", "#5e5ce6"];

/** Bottom-sheet shell so these forms pop up over the screen instead of appending below a long list. */
function SettingsSheet({ onClose, children }: { onClose: () => void; children: React.ReactNode }) {
  return (
    <div className="fixed inset-0 z-[60] flex items-end justify-center">
      <button className="absolute inset-0 bg-black/55 backdrop-blur-sm" onClick={onClose} aria-label="Close" />
      <div className="relative w-full max-w-md glass-panel rounded-t-[28px] rounded-b-none px-5 pt-4 pb-[max(1.25rem,env(safe-area-inset-bottom))] flex flex-col gap-3.5 max-h-[86vh] overflow-y-auto">
        <div className="w-9 h-1 rounded-full bg-[var(--muted)] opacity-40 mx-auto" />
        {children}
      </div>
    </div>
  );
}

export default function SettingsPage() {
  const router = useRouter();
  const { vehicles, types, loading, refresh } = useGarageData();
  const [addingVehicle, setAddingVehicle] = useState(false);
  const [settingOdometerFor, setSettingOdometerFor] = useState<Vehicle | null>(null);
  const [addingTypeFor, setAddingTypeFor] = useState<string | "all" | null>(null);
  const [editingType, setEditingType] = useState<MaintenanceType | null>(null);
  const [presetSet, setPresetSet] = useState<"generic" | "tacoma2024" | null>(null);
  const [manualBusyFor, setManualBusyFor] = useState<string | null>(null);
  const manualInputRef = useRef<HTMLInputElement>(null);
  const pendingManualVehicle = useRef<string | null>(null);

  async function signOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/login");
  }

  async function deleteVehicle(id: string) {
    const supabase = createClient();
    await supabase.from("vehicles").delete().eq("id", id);
    await refresh();
  }

  async function moveVehicle(index: number, direction: -1 | 1) {
    const other = vehicles[index + direction];
    const current = vehicles[index];
    if (!other) return;
    const supabase = createClient();
    await Promise.all([
      supabase.from("vehicles").update({ sort_order: other.sort_order }).eq("id", current.id),
      supabase.from("vehicles").update({ sort_order: current.sort_order }).eq("id", other.id),
    ]);
    await refresh();
  }

  function pickManual(vehicleId: string) {
    pendingManualVehicle.current = vehicleId;
    manualInputRef.current?.click();
  }

  async function handleManualFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    const vehicleId = pendingManualVehicle.current;
    e.target.value = "";
    if (!file || !vehicleId) return;

    setManualBusyFor(vehicleId);
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setManualBusyFor(null);
      return;
    }

    const path = `${user.id}/${vehicleId}.pdf`;
    const { error: uploadError } = await supabase.storage
      .from("manuals")
      .upload(path, file, { upsert: true, contentType: "application/pdf" });

    if (!uploadError) {
      await supabase.from("vehicles").update({ manual_uploaded_at: new Date().toISOString() }).eq("id", vehicleId);
      await refresh();
    }
    setManualBusyFor(null);
  }

  async function viewManual(vehicleId: string) {
    setManualBusyFor(vehicleId);
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setManualBusyFor(null);
      return;
    }
    const path = `${user.id}/${vehicleId}.pdf`;
    const { data } = await supabase.storage.from("manuals").createSignedUrl(path, 60 * 60);
    setManualBusyFor(null);
    if (data?.signedUrl) window.open(data.signedUrl, "_blank");
  }

  async function deleteManual(vehicleId: string) {
    setManualBusyFor(vehicleId);
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setManualBusyFor(null);
      return;
    }
    const path = `${user.id}/${vehicleId}.pdf`;
    await supabase.storage.from("manuals").remove([path]);
    await supabase.from("vehicles").update({ manual_uploaded_at: null }).eq("id", vehicleId);
    await refresh();
    setManualBusyFor(null);
  }

  async function deleteType(id: string) {
    const supabase = createClient();
    await supabase.from("maintenance_types").delete().eq("id", id);
    await refresh();
  }

  if (loading) {
    return (
      <main className="flex-1 flex items-center justify-center">
        <Loader2 className="w-6 h-6 animate-spin text-muted" />
      </main>
    );
  }

  return (
    <main className="flex-1 px-5 pt-[calc(env(safe-area-inset-top)+1.5rem)] pb-40 flex flex-col gap-7">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-xs font-medium tracking-[0.14em] uppercase text-muted">Garage</p>
          <h1 className="text-2xl font-semibold tracking-tight mt-0.5">Settings</h1>
        </div>
        <button onClick={signOut} className="glass-panel w-11 h-11 rounded-full flex items-center justify-center text-muted">
          <LogOut className="w-4.5 h-4.5" strokeWidth={1.75} />
        </button>
      </div>

      {/* Vehicles */}
      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between px-1">
          <h3 className="text-sm font-semibold text-muted">Vehicles</h3>
          <button onClick={() => setAddingVehicle(true)} className="text-sm font-medium text-accent flex items-center gap-1">
            <Plus className="w-4 h-4" /> Add
          </button>
        </div>

        <input
          ref={manualInputRef}
          type="file"
          accept="application/pdf"
          className="hidden"
          onChange={handleManualFile}
        />

        <div className="flex flex-col gap-2.5">
          {vehicles.map((v, i) => (
            <div key={v.id} className="glass-panel rounded-3xl px-4 py-3.5 flex items-center gap-3.5">
              {vehicles.length > 1 && (
                <div className="flex flex-col shrink-0 -my-1">
                  <button
                    onClick={() => moveVehicle(i, -1)}
                    disabled={i === 0}
                    className="text-muted p-1 disabled:opacity-25"
                    aria-label={`Move ${v.name} up`}
                  >
                    <ChevronUp className="w-3.5 h-3.5" />
                  </button>
                  <button
                    onClick={() => moveVehicle(i, 1)}
                    disabled={i === vehicles.length - 1}
                    className="text-muted p-1 disabled:opacity-25"
                    aria-label={`Move ${v.name} down`}
                  >
                    <ChevronDown className="w-3.5 h-3.5" />
                  </button>
                </div>
              )}
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate">
                  {v.year} {v.make} {v.name}
                </p>
                <p className="text-xs text-muted truncate">
                  {v.current_mileage.toLocaleString()} mi · ~{v.avg_daily_miles} mi/day
                </p>
              </div>

              {manualBusyFor === v.id ? (
                <div className="p-2">
                  <Loader2 className="w-4 h-4 animate-spin text-muted" />
                </div>
              ) : v.manual_uploaded_at ? (
                <div className="flex items-center gap-1 shrink-0">
                  <button onClick={() => viewManual(v.id)} className="text-accent p-2" aria-label="View manual" title="View manual">
                    <FileText className="w-4 h-4" />
                  </button>
                  <button onClick={() => deleteManual(v.id)} className="text-muted p-2" aria-label="Remove manual" title="Remove manual">
                    <X className="w-4 h-4" />
                  </button>
                </div>
              ) : (
                <button
                  onClick={() => pickManual(v.id)}
                  className="text-muted p-2 shrink-0"
                  aria-label="Add owner's manual"
                  title="Add owner's manual"
                >
                  <Upload className="w-4 h-4" />
                </button>
              )}

              <button
                onClick={() => setSettingOdometerFor(v)}
                className="text-muted p-2 shrink-0"
                aria-label={`Set ${v.name} odometer`}
                title="Set odometer"
              >
                <Gauge className="w-4 h-4" />
              </button>

              <button onClick={() => deleteVehicle(v.id)} className="text-muted p-2 shrink-0">
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>

        {settingOdometerFor && (
          <SettingsSheet onClose={() => setSettingOdometerFor(null)}>
            <OdometerForm
              vehicle={settingOdometerFor}
              onClose={() => setSettingOdometerFor(null)}
              onSaved={async () => {
                setSettingOdometerFor(null);
                await refresh();
              }}
            />
          </SettingsSheet>
        )}

        {addingVehicle && (
          <SettingsSheet onClose={() => setAddingVehicle(false)}>
            <VehicleForm
              onClose={() => setAddingVehicle(false)}
              onSaved={async () => {
                setAddingVehicle(false);
                await refresh();
              }}
            />
          </SettingsSheet>
        )}
      </section>

      {/* Maintenance types */}
      <section className="flex flex-col gap-3">
        <div className="flex items-center justify-between px-1">
          <h3 className="text-sm font-semibold text-muted">Maintenance types</h3>
          <button
            onClick={() => setAddingTypeFor("all")}
            className="text-sm font-medium text-accent flex items-center gap-1"
            disabled={vehicles.length === 0}
          >
            <Plus className="w-4 h-4" /> Add
          </button>
        </div>

        <div className="flex gap-2 px-1">
          <button
            onClick={() => setPresetSet("tacoma2024")}
            className="glass-panel rounded-full px-3.5 py-1.5 text-xs font-medium text-accent disabled:opacity-40"
            disabled={vehicles.length === 0}
          >
            2024 Tacoma preset
          </button>
          <button
            onClick={() => setPresetSet("generic")}
            className="glass-panel rounded-full px-3.5 py-1.5 text-xs font-medium text-accent disabled:opacity-40"
            disabled={vehicles.length === 0}
          >
            Quick add
          </button>
        </div>

        <div className="flex flex-col gap-2.5">
          {types.map((t) => (
            <div key={t.id} className="glass-panel rounded-3xl px-4 py-3.5 flex items-center gap-3.5">
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate">{t.name}</p>
                <p className="text-xs text-muted truncate">
                  {t.interval_miles ? `${t.interval_miles.toLocaleString()} mi` : ""}
                  {t.interval_miles && t.interval_days ? " · " : ""}
                  {t.interval_days ? `${t.interval_days} days` : ""}
                  {!t.interval_miles && !t.interval_days ? "No reminder" : ""}
                  {" · "}
                  {t.vehicle_id ? vehicles.find((v) => v.id === t.vehicle_id)?.name ?? "Vehicle" : "All vehicles"}
                </p>
              </div>
              <button onClick={() => setEditingType(t)} className="text-muted p-2" aria-label={`Edit ${t.name}`}>
                <Pencil className="w-4 h-4" />
              </button>
              <button onClick={() => deleteType(t.id)} className="text-muted p-2" aria-label={`Delete ${t.name}`}>
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>

        {addingTypeFor && (
          <SettingsSheet onClose={() => setAddingTypeFor(null)}>
            <TypeForm
              vehicles={vehicles}
              onClose={() => setAddingTypeFor(null)}
              onSaved={async () => {
                setAddingTypeFor(null);
                await refresh();
              }}
            />
          </SettingsSheet>
        )}

        {editingType && (
          <SettingsSheet onClose={() => setEditingType(null)}>
            <TypeForm
              vehicles={vehicles}
              editingType={editingType}
              onClose={() => setEditingType(null)}
              onSaved={async () => {
                setEditingType(null);
                await refresh();
              }}
            />
          </SettingsSheet>
        )}

        {presetSet && (
          <SettingsSheet onClose={() => setPresetSet(null)}>
            <PresetPicker
              vehicles={vehicles}
              presets={presetSet === "tacoma2024" ? TACOMA_2024_PRESETS : MAINTENANCE_PRESETS}
              title={presetSet === "tacoma2024" ? "2024 Tacoma schedule" : "Quick add common services"}
              description={
                presetSet === "tacoma2024"
                  ? "Pulled directly from Toyota's official 2024 Tacoma Warranty & Maintenance Guide (normal driving conditions). Items only scheduled under towing/dirt-road conditions were left out rather than guessed at."
                  : "General guidelines to start from — check each vehicle's owner's manual for exact intervals, then edit or delete any of these later."
              }
              onClose={() => setPresetSet(null)}
              onSaved={async () => {
                setPresetSet(null);
                await refresh();
              }}
            />
          </SettingsSheet>
        )}
      </section>
    </main>
  );
}

/**
 * Corrects a vehicle's odometer by logging a fresh reading dated right now.
 * The DB derives vehicles.current_mileage from the newest log, so this takes
 * effect immediately and resets the projection baseline.
 */
function OdometerForm({ vehicle, onClose, onSaved }: { vehicle: Vehicle; onClose: () => void; onSaved: () => void }) {
  const [mileage, setMileage] = useState(String(vehicle.current_mileage));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    const value = Number(mileage);
    if (!Number.isFinite(value) || value < 0) {
      setError("Enter a valid mileage.");
      return;
    }
    setSaving(true);
    setError(null);
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setSaving(false);
      return;
    }
    const { error: insertError } = await supabase.from("mileage_logs").insert({
      user_id: user.id,
      vehicle_id: vehicle.id,
      mileage: Math.round(value),
      note: "Odometer correction",
      recorded_at: new Date().toISOString(),
    });
    setSaving(false);
    if (insertError) {
      setError(insertError.message);
      return;
    }
    onSaved();
  }

  return (
    <form onSubmit={save} className="flex flex-col gap-3.5">
      <div className="flex items-center justify-between">
        <p className="text-sm font-semibold">Set odometer · {vehicle.name}</p>
        <button type="button" onClick={onClose} className="text-muted">
          <X className="w-4 h-4" />
        </button>
      </div>
      <Field label="Actual odometer reading" value={mileage} onChange={setMileage} type="number" />
      <p className="text-xs text-muted">Saves a new reading dated now, so it becomes the truck&apos;s current mileage.</p>
      {error && <p className="text-xs text-red-400">{error}</p>}
      <button type="submit" disabled={saving} className="btn-accent rounded-2xl py-3 text-sm font-medium flex items-center justify-center gap-2 disabled:opacity-60">
        {saving && <Loader2 className="w-4 h-4 animate-spin" />}
        Save odometer
      </button>
    </form>
  );
}

function VehicleForm({ onClose, onSaved }: { onClose: () => void; onSaved: () => void }) {
  const [name, setName] = useState("");
  const [make, setMake] = useState("Toyota");
  const [model, setModel] = useState("");
  const [year, setYear] = useState(new Date().getFullYear());
  const [mileage, setMileage] = useState("0");
  const [avgDaily, setAvgDaily] = useState("25");
  const [icon, setIcon] = useState("truck");
  const [color, setColor] = useState(ACCENT_OPTIONS[0]);
  const [saving, setSaving] = useState(false);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;
    await supabase.from("vehicles").insert({
      user_id: user.id,
      name,
      make,
      model,
      year: Number(year),
      current_mileage: Number(mileage),
      avg_daily_miles: Number(avgDaily),
      icon,
      color,
    });
    setSaving(false);
    onSaved();
  }

  return (
    <form onSubmit={save} className="flex flex-col gap-3.5">
      <div className="flex items-center justify-between">
        <p className="text-sm font-semibold">New vehicle</p>
        <button type="button" onClick={onClose} className="text-muted">
          <X className="w-4 h-4" />
        </button>
      </div>

      <div className="flex gap-2">
        {ICON_OPTIONS.map(({ value, icon: Icon }) => (
          <button
            key={value}
            type="button"
            onClick={() => setIcon(value)}
            className="flex-1 min-w-0 glass-input rounded-2xl py-3 flex items-center justify-center"
            style={{ borderColor: icon === value ? color : undefined, color: icon === value ? color : "var(--muted)" }}
          >
            <Icon className="w-5 h-5" strokeWidth={1.75} />
          </button>
        ))}
      </div>

      <div className="flex gap-2">
        {ACCENT_OPTIONS.map((c) => (
          <button
            key={c}
            type="button"
            onClick={() => setColor(c)}
            className="w-8 h-8 rounded-full shrink-0"
            style={{ background: c, outline: color === c ? `2px solid ${c}` : "none", outlineOffset: 2 }}
          />
        ))}
      </div>

      <Field label="Nickname" value={name} onChange={setName} placeholder="Tacoma" required />
      <div className="flex gap-3 min-w-0">
        <Field label="Year" value={String(year)} onChange={(v) => setYear(Number(v) || year)} type="number" />
        <Field label="Make" value={make} onChange={setMake} />
      </div>
      <Field label="Model" value={model} onChange={setModel} placeholder="Tacoma TRD Off-Road" />
      <div className="flex gap-3 min-w-0">
        <Field label="Current mileage" value={mileage} onChange={setMileage} type="number" />
        <Field label="Avg mi/day" value={avgDaily} onChange={setAvgDaily} type="number" />
      </div>

      <button type="submit" disabled={saving} className="btn-accent rounded-2xl py-3 text-sm font-medium flex items-center justify-center gap-2 disabled:opacity-60">
        {saving && <Loader2 className="w-4 h-4 animate-spin" />}
        Save vehicle
      </button>
    </form>
  );
}

function PresetPicker({
  vehicles,
  presets,
  title,
  description,
  onClose,
  onSaved,
}: {
  vehicles: { id: string; name: string }[];
  presets: MaintenancePreset[];
  title: string;
  description: string;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [selected, setSelected] = useState<Set<string>>(new Set(presets.map((p) => p.name)));
  const [scope, setScope] = useState<string>("");
  const [saving, setSaving] = useState(false);

  function toggle(name: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(name)) next.delete(name);
      else next.add(name);
      return next;
    });
  }

  async function save() {
    if (selected.size === 0) return;
    setSaving(true);
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;

    const rows = presets.filter((p) => selected.has(p.name)).map((p) => ({
      user_id: user.id,
      vehicle_id: scope || null,
      name: p.name,
      category: p.category,
      icon: p.icon,
      interval_miles: p.interval_miles,
      interval_days: p.interval_days,
    }));

    await supabase.from("maintenance_types").insert(rows);
    setSaving(false);
    onSaved();
  }

  return (
    <div className="flex flex-col gap-3.5">
      <div className="flex items-center justify-between">
        <p className="text-sm font-semibold">{title}</p>
        <button type="button" onClick={onClose} className="text-muted">
          <X className="w-4 h-4" />
        </button>
      </div>
      <p className="text-xs text-muted -mt-2">{description}</p>

      <label className="flex flex-col gap-2">
        <span className="text-xs font-medium text-muted uppercase tracking-wide">Applies to</span>
        <select value={scope} onChange={(e) => setScope(e.target.value)} className="glass-input w-0 min-w-full rounded-2xl px-4 py-3 text-sm outline-none">
          <option value="">All vehicles</option>
          {vehicles.map((v) => (
            <option key={v.id} value={v.id}>
              {v.name}
            </option>
          ))}
        </select>
      </label>

      <div className="flex flex-col gap-2">
        {presets.map((p) => {
          const checked = selected.has(p.name);
          const detail = [
            p.interval_miles ? `${p.interval_miles.toLocaleString()} mi` : null,
            p.interval_days ? `${p.interval_days} days` : null,
          ]
            .filter(Boolean)
            .join(" · ");
          return (
            <button
              key={p.name}
              type="button"
              onClick={() => toggle(p.name)}
              className="glass-input w-full min-w-0 rounded-2xl px-4 py-3 flex items-center justify-between gap-3 text-left"
              style={{ borderColor: checked ? "var(--accent)" : undefined }}
            >
              <span className="min-w-0">
                <span className="block text-sm font-medium truncate">{p.name}</span>
                <span className="block text-xs text-muted truncate">{detail}</span>
              </span>
              <span
                className="w-5 h-5 rounded-full border shrink-0 flex items-center justify-center"
                style={{ borderColor: checked ? "var(--accent)" : "var(--glass-border)", background: checked ? "var(--accent)" : "transparent" }}
              >
                {checked && <span className="w-2 h-2 rounded-full" style={{ background: "var(--accent-foreground)" }} />}
              </span>
            </button>
          );
        })}
      </div>

      <button
        onClick={save}
        disabled={saving || selected.size === 0}
        className="btn-accent rounded-2xl py-3 text-sm font-medium flex items-center justify-center gap-2 disabled:opacity-60"
      >
        {saving && <Loader2 className="w-4 h-4 animate-spin" />}
        Add {selected.size} type{selected.size === 1 ? "" : "s"}
      </button>
    </div>
  );
}

function TypeForm({
  vehicles,
  editingType,
  onClose,
  onSaved,
}: {
  vehicles: { id: string; name: string }[];
  editingType?: MaintenanceType;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [name, setName] = useState(editingType?.name ?? "");
  const [category, setCategory] = useState<(typeof MAINTENANCE_CATEGORIES)[number]["value"]>(editingType?.category ?? "custom");
  const [intervalMiles, setIntervalMiles] = useState(editingType?.interval_miles != null ? String(editingType.interval_miles) : "");
  const [intervalDays, setIntervalDays] = useState(editingType?.interval_days != null ? String(editingType.interval_days) : "");
  const [scope, setScope] = useState<string>(editingType?.vehicle_id ?? "");
  const [saving, setSaving] = useState(false);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    const supabase = createClient();
    const catMeta = MAINTENANCE_CATEGORIES.find((c) => c.value === category);

    if (editingType) {
      await supabase
        .from("maintenance_types")
        .update({
          vehicle_id: scope || null,
          name: name || catMeta?.label,
          category,
          icon: catMeta?.icon ?? "wrench",
          interval_miles: intervalMiles ? Number(intervalMiles) : null,
          interval_days: intervalDays ? Number(intervalDays) : null,
        })
        .eq("id", editingType.id);
    } else {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      await supabase.from("maintenance_types").insert({
        user_id: user.id,
        vehicle_id: scope || null,
        name: name || catMeta?.label,
        category,
        icon: catMeta?.icon ?? "wrench",
        interval_miles: intervalMiles ? Number(intervalMiles) : null,
        interval_days: intervalDays ? Number(intervalDays) : null,
      });
    }
    setSaving(false);
    onSaved();
  }

  return (
    <form onSubmit={save} className="flex flex-col gap-3.5">
      <div className="flex items-center justify-between">
        <p className="text-sm font-semibold">{editingType ? "Edit maintenance type" : "New maintenance type"}</p>
        <button type="button" onClick={onClose} className="text-muted">
          <X className="w-4 h-4" />
        </button>
      </div>

      <div className="flex flex-wrap gap-2">
        {MAINTENANCE_CATEGORIES.map((c) => (
          <button
            key={c.value}
            type="button"
            onClick={() => setCategory(c.value)}
            className="text-xs font-medium px-3 py-2 rounded-full glass-input"
            style={{ color: category === c.value ? "var(--accent)" : "var(--muted)", borderColor: category === c.value ? "var(--accent)" : undefined }}
          >
            {c.label}
          </button>
        ))}
      </div>

      <Field label="Name" value={name} onChange={setName} placeholder="Oil Change" />

      <div className="flex gap-3 min-w-0">
        <Field label="Every (mi)" value={intervalMiles} onChange={setIntervalMiles} type="number" placeholder="5000" />
        <Field label="Every (days)" value={intervalDays} onChange={setIntervalDays} type="number" placeholder="180" />
      </div>

      <label className="flex flex-col gap-2">
        <span className="text-xs font-medium text-muted uppercase tracking-wide">Applies to</span>
        <select value={scope} onChange={(e) => setScope(e.target.value)} className="glass-input w-0 min-w-full rounded-2xl px-4 py-3 text-sm outline-none">
          <option value="">All vehicles</option>
          {vehicles.map((v) => (
            <option key={v.id} value={v.id}>
              {v.name}
            </option>
          ))}
        </select>
      </label>

      <button type="submit" disabled={saving} className="btn-accent rounded-2xl py-3 text-sm font-medium flex items-center justify-center gap-2 disabled:opacity-60">
        {saving && <Loader2 className="w-4 h-4 animate-spin" />}
        {editingType ? "Save changes" : "Save type"}
      </button>
    </form>
  );
}

function Field({
  label,
  value,
  onChange,
  type = "text",
  placeholder,
  required,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  type?: string;
  placeholder?: string;
  required?: boolean;
}) {
  return (
    <label className="flex flex-col gap-2 flex-1 min-w-0">
      <span className="text-xs font-medium text-muted uppercase tracking-wide">{label}</span>
      <input
        type={type}
        value={value}
        required={required}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        className="glass-input w-0 min-w-full rounded-2xl px-4 py-3 text-sm outline-none"
      />
    </label>
  );
}
