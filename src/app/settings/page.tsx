"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2, Plus, Trash2, Car, Truck, LogOut, X } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { useGarageData } from "@/lib/useGarageData";
import { MAINTENANCE_CATEGORIES } from "@/lib/types";

const ICON_OPTIONS: { value: string; icon: typeof Car }[] = [
  { value: "truck", icon: Truck },
  { value: "car", icon: Car },
];

const ACCENT_OPTIONS = ["#e6d3c1", "#ff6a3d", "#0a84ff", "#34c759", "#af52de", "#ff375f", "#5e5ce6"];

export default function SettingsPage() {
  const router = useRouter();
  const { vehicles, types, loading, refresh } = useGarageData();
  const [addingVehicle, setAddingVehicle] = useState(false);
  const [addingTypeFor, setAddingTypeFor] = useState<string | "all" | null>(null);

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
    <main className="flex-1 px-5 pt-[max(1.5rem,env(safe-area-inset-top))] pb-40 flex flex-col gap-7">
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

        <div className="flex flex-col gap-2.5">
          {vehicles.map((v) => (
            <div key={v.id} className="glass-panel rounded-3xl px-4 py-3.5 flex items-center gap-3.5">
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate">
                  {v.year} {v.make} {v.name}
                </p>
                <p className="text-xs text-muted truncate">
                  {v.current_mileage.toLocaleString()} mi · ~{v.avg_daily_miles} mi/day
                </p>
              </div>
              <button onClick={() => deleteVehicle(v.id)} className="text-muted p-2">
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>

        {addingVehicle && (
          <VehicleForm
            onClose={() => setAddingVehicle(false)}
            onSaved={async () => {
              setAddingVehicle(false);
              await refresh();
            }}
          />
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
              <button onClick={() => deleteType(t.id)} className="text-muted p-2">
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>

        {addingTypeFor && (
          <TypeForm
            vehicles={vehicles}
            onClose={() => setAddingTypeFor(null)}
            onSaved={async () => {
              setAddingTypeFor(null);
              await refresh();
            }}
          />
        )}
      </section>
    </main>
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
    <form onSubmit={save} className="glass-panel rounded-3xl p-5 flex flex-col gap-3.5 mt-1">
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
            className="flex-1 glass-input rounded-2xl py-3 flex items-center justify-center"
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
      <div className="flex gap-3">
        <Field label="Year" value={String(year)} onChange={(v) => setYear(Number(v) || year)} type="number" />
        <Field label="Make" value={make} onChange={setMake} />
      </div>
      <Field label="Model" value={model} onChange={setModel} placeholder="Tacoma TRD Off-Road" />
      <div className="flex gap-3">
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

function TypeForm({
  vehicles,
  onClose,
  onSaved,
}: {
  vehicles: { id: string; name: string }[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [name, setName] = useState("");
  const [category, setCategory] = useState<(typeof MAINTENANCE_CATEGORIES)[number]["value"]>("custom");
  const [intervalMiles, setIntervalMiles] = useState("");
  const [intervalDays, setIntervalDays] = useState("");
  const [scope, setScope] = useState<string>("");
  const [saving, setSaving] = useState(false);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;
    const catMeta = MAINTENANCE_CATEGORIES.find((c) => c.value === category);
    await supabase.from("maintenance_types").insert({
      user_id: user.id,
      vehicle_id: scope || null,
      name: name || catMeta?.label,
      category,
      icon: catMeta?.icon ?? "wrench",
      interval_miles: intervalMiles ? Number(intervalMiles) : null,
      interval_days: intervalDays ? Number(intervalDays) : null,
    });
    setSaving(false);
    onSaved();
  }

  return (
    <form onSubmit={save} className="glass-panel rounded-3xl p-5 flex flex-col gap-3.5 mt-1">
      <div className="flex items-center justify-between">
        <p className="text-sm font-semibold">New maintenance type</p>
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

      <div className="flex gap-3">
        <Field label="Every (mi)" value={intervalMiles} onChange={setIntervalMiles} type="number" placeholder="5000" />
        <Field label="Every (days)" value={intervalDays} onChange={setIntervalDays} type="number" placeholder="180" />
      </div>

      <label className="flex flex-col gap-2">
        <span className="text-xs font-medium text-muted uppercase tracking-wide">Applies to</span>
        <select value={scope} onChange={(e) => setScope(e.target.value)} className="glass-input rounded-2xl px-4 py-3 text-sm outline-none">
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
        Save type
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
    <label className="flex flex-col gap-2 flex-1">
      <span className="text-xs font-medium text-muted uppercase tracking-wide">{label}</span>
      <input
        type={type}
        value={value}
        required={required}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        className="glass-input rounded-2xl px-4 py-3 text-sm outline-none"
      />
    </label>
  );
}
