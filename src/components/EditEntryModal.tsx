"use client";

import { useRef, useState } from "react";
import { Loader2, Camera, X, Trash2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { usePhotoUrls } from "@/lib/usePhotoUrls";
import type { MaintenanceLog, MaintenancePhoto, MaintenanceType } from "@/lib/types";

type PendingPhoto = { file: File; previewUrl: string };

export default function EditEntryModal({
  log,
  types,
  photos,
  onClose,
  onSaved,
}: {
  log: MaintenanceLog;
  types: MaintenanceType[];
  photos: MaintenancePhoto[];
  onClose: () => void;
  onSaved: () => Promise<void> | void;
}) {
  const vehicleTypes = types.filter((t) => t.vehicle_id === null || t.vehicle_id === log.vehicle_id);
  const [typeId, setTypeId] = useState(log.maintenance_type_id ?? "");
  const [mileage, setMileage] = useState(String(log.mileage_at));
  const [date, setDate] = useState(log.performed_at.slice(0, 10));
  const [cost, setCost] = useState(log.cost != null ? String(log.cost) : "");
  const [notes, setNotes] = useState(log.notes ?? "");
  const [newPhotos, setNewPhotos] = useState<PendingPhoto[]>([]);
  const photoInputRef = useRef<HTMLInputElement>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const existingPhotoUrls = usePhotoUrls(photos);

  function addPhotos(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files ?? []);
    e.target.value = "";
    setNewPhotos((prev) => [...prev, ...files.map((file) => ({ file, previewUrl: URL.createObjectURL(file) }))]);
  }

  function removeNewPhoto(index: number) {
    setNewPhotos((prev) => {
      URL.revokeObjectURL(prev[index].previewUrl);
      return prev.filter((_, i) => i !== index);
    });
  }

  async function removeExistingPhoto(photo: MaintenancePhoto) {
    const supabase = createClient();
    await supabase.storage.from("maintenance-photos").remove([photo.storage_path]);
    await supabase.from("maintenance_photos").delete().eq("id", photo.id);
    await onSaved();
  }

  async function save() {
    setSaving(true);
    setError("");
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setSaving(false);
      setError("You're signed out — please sign in again.");
      return;
    }

    const type = vehicleTypes.find((t) => t.id === typeId);
    const { error: updateError } = await supabase
      .from("maintenance_logs")
      .update({
        maintenance_type_id: typeId || null,
        title: type?.name ?? log.title,
        notes,
        cost: cost ? Number(cost) : null,
        mileage_at: Number(mileage),
        performed_at: new Date(date + "T12:00:00").toISOString(),
      })
      .eq("id", log.id);

    if (updateError) {
      setSaving(false);
      setError(updateError.message);
      return;
    }

    if (newPhotos.length > 0) {
      for (const photo of newPhotos) {
        const ext = photo.file.name.split(".").pop() || "jpg";
        const path = `${user.id}/${log.id}/${crypto.randomUUID()}.${ext}`;
        const { error: uploadError } = await supabase.storage
          .from("maintenance-photos")
          .upload(path, photo.file, { contentType: photo.file.type || "image/jpeg" });
        if (!uploadError) {
          await supabase.from("maintenance_photos").insert({
            user_id: user.id,
            maintenance_log_id: log.id,
            storage_path: path,
          });
        }
      }
      newPhotos.forEach((p) => URL.revokeObjectURL(p.previewUrl));
    }

    await onSaved();
    setSaving(false);
    onClose();
  }

  async function remove() {
    setSaving(true);
    const supabase = createClient();
    await supabase.from("maintenance_logs").delete().eq("id", log.id);
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
          <h2 className="text-lg font-semibold tracking-tight">Edit Entry</h2>
          <button onClick={onClose} className="glass-panel w-8 h-8 rounded-full flex items-center justify-center text-muted" aria-label="Close">
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="form-panel">
          <label className="form-row">
            <span className="form-label">Type</span>
            <select value={typeId} onChange={(e) => setTypeId(e.target.value)} className="form-field">
              {vehicleTypes.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                </option>
              ))}
            </select>
          </label>

          <label className="form-row">
            <span className="form-label">Odometer (mi)</span>
            <input
              type="number"
              required
              inputMode="numeric"
              value={mileage}
              onChange={(e) => setMileage(e.target.value)}
              className="form-field"
            />
          </label>

          <label className="form-row">
            <span className="form-label">Date</span>
            <input type="date" required value={date} onChange={(e) => setDate(e.target.value)} className="form-field" />
          </label>

          <label className="form-row">
            <span className="form-label">Cost ($, optional)</span>
            <input type="number" inputMode="decimal" value={cost} onChange={(e) => setCost(e.target.value)} className="form-field" />
          </label>

          <label className="form-row">
            <span className="form-label">Notes</span>
            <textarea value={notes} onChange={(e) => setNotes(e.target.value)} rows={2} className="form-field resize-none" />
          </label>

          <div className="form-row">
            <span className="form-label">Photos</span>
            <input ref={photoInputRef} type="file" accept="image/*" multiple className="hidden" onChange={addPhotos} />
            <div className="flex flex-wrap gap-2.5 mt-1">
              {photos.map((p) => {
                const url = existingPhotoUrls[p.storage_path];
                return (
                  <div key={p.id} className="relative w-16 h-16 shrink-0">
                    {url && (
                      /* eslint-disable-next-line @next/next/no-img-element */
                      <img src={url} alt="" className="w-full h-full object-cover rounded-xl" />
                    )}
                    <button
                      type="button"
                      onClick={() => removeExistingPhoto(p)}
                      className="absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-black/70 flex items-center justify-center text-white"
                      aria-label="Remove photo"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  </div>
                );
              })}
              {newPhotos.map((p, i) => (
                <div key={p.previewUrl} className="relative w-16 h-16 shrink-0">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={p.previewUrl} alt="" className="w-full h-full object-cover rounded-xl" />
                  <button
                    type="button"
                    onClick={() => removeNewPhoto(i)}
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
        </div>

        {error && (
          <p className="text-xs text-center" style={{ color: "var(--status-overdue)" }}>
            {error}
          </p>
        )}

        <button
          onClick={save}
          disabled={saving}
          className="btn-accent rounded-2xl py-3.5 text-sm font-medium flex items-center justify-center gap-2 disabled:opacity-60"
        >
          {saving && <Loader2 className="w-4 h-4 animate-spin" />}
          Save changes
        </button>

        <button
          onClick={remove}
          disabled={saving}
          className="flex items-center justify-center gap-1.5 text-xs font-medium disabled:opacity-60 pb-1"
          style={{ color: "var(--status-overdue)" }}
        >
          <Trash2 className="w-3.5 h-3.5" />
          Delete entry
        </button>
      </div>
    </div>
  );
}
