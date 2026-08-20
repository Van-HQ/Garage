"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { MaintenancePhoto } from "@/lib/types";

/** Resolves private-bucket photo paths to signed URLs, keyed by storage_path. */
export function usePhotoUrls(photos: MaintenancePhoto[]) {
  const [urls, setUrls] = useState<Record<string, string>>({});

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
        setUrls(map);
      });
    return () => {
      cancelled = true;
    };
  }, [photos]);

  return urls;
}
