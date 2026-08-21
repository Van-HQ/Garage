"use client";

import { useState } from "react";
import { Loader2, X } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import type { MaintenanceLog, MaintenanceType } from "@/lib/types";

export default function EditCareItemModal({
  type,
  lastLog,
  onClose,
  onSaved,
}: {
  type: MaintenanceType;
  lastLog: MaintenanceLog | null;
  onClose: () => void;
  onSaved: () => Promise<void> | void;
}) {
  const [mileage, setMileage] = useState(String(type.baseline_mileage ?? ""));
  const [date, setDate] = useState((type.baseline_date ?? type.created_at).slice(0, 10));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function save() {
    setSaving(true);
    setError("");
    const supabase = createClient();
    const { error: updateError } = await supabase
      .from("maintenance_types")
      .update({
        baseline_mileage: mileage ? Number(mileage) : null,
        baseline_date: date ? new Date(date + "T12:00:00").toISOString() : null,
      })
      .eq("id", type.id);

    if (updateError) {
      setSaving(false);
      setError(updateError.message);
      return;
    }

    await onSaved();
    setSaving(false);
    onClose();
  }

  return (
    <div className="fixed inset-0 z-[60] flex items-end justify-center">
      <button className="absolute inset-0 bg-black/55 backdrop-blur-sm" onClick={onClose} aria-label="Close" />
      <div className="relative w-full max-w-md glass-panel rounded-t-[28px] rounded-b-none px-5 pt-4 pb-[max(1.25rem,env(safe-area-inset-bottom))] flex flex-col gap-4 max-h-[88vh] overflow-y-auto">
        <div className="w-9 h-1 rounded-full bg-[var(--muted)] opacity-40 mx-auto" />

        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold tracking-tight">{type.name}</h2>
            <p className="text-xs text-muted mt-0.5">Set where this item starts counting from</p>
          </div>
          <button onClick={onClose} className="glass-panel w-8 h-8 rounded-full flex items-center justify-center text-muted shrink-0" aria-label="Close">
            <X className="w-4 h-4" />
          </button>
        </div>

        {lastLog ? (
          <div className="form-panel">
            <div className="form-row">
              <span className="form-label">Already logged</span>
              <p className="text-[15px]">
                Last done{" "}
                {new Date(lastLog.performed_at).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" })} at{" "}
                {lastLog.mileage_at.toLocaleString()} mi — that log is the current starting point. Delete it in History to fall back to a manual baseline.
              </p>
            </div>
          </div>
        ) : (
          <div className="form-panel">
            <label className="form-row">
              <span className="form-label">Starting mileage</span>
              <input
                type="number"
                inputMode="numeric"
                placeholder="e.g. 0"
                value={mileage}
                onChange={(e) => setMileage(e.target.value)}
                className="form-field"
              />
            </label>
            <label className="form-row">
              <span className="form-label">Starting date</span>
              <input type="date" value={date} onChange={(e) => setDate(e.target.value)} className="form-field" />
            </label>
          </div>
        )}

        {error && (
          <p className="text-xs text-center" style={{ color: "var(--status-overdue)" }}>
            {error}
          </p>
        )}

        {!lastLog && (
          <button
            onClick={save}
            disabled={saving}
            className="btn-accent rounded-2xl py-3.5 text-sm font-medium flex items-center justify-center gap-2 disabled:opacity-60"
          >
            {saving && <Loader2 className="w-4 h-4 animate-spin" />}
            Save
          </button>
        )}
      </div>
    </div>
  );
}
