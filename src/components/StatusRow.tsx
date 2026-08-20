import Link from "next/link";
import { ChevronRight } from "lucide-react";
import type { MaintenanceStatusItem } from "@/lib/maintenance-status";
import { MAINTENANCE_ICONS } from "@/lib/maintenance-icons";

const STATUS_COLOR: Record<MaintenanceStatusItem["status"], string> = {
  overdue: "var(--status-overdue)",
  "due-soon": "var(--status-soon)",
  ok: "var(--status-ok)",
  unscheduled: "var(--muted)",
};

const STATUS_LABEL: Record<MaintenanceStatusItem["status"], string> = {
  overdue: "Overdue",
  "due-soon": "Due soon",
  ok: "On track",
  unscheduled: "Not logged",
};

export default function StatusRow({ item, vehicleId }: { item: MaintenanceStatusItem; vehicleId: string }) {
  const Icon = MAINTENANCE_ICONS[item.type.icon] ?? MAINTENANCE_ICONS.wrench;
  const color = STATUS_COLOR[item.status];

  let detail = "No interval set";
  if (item.milesRemaining != null && item.daysRemaining != null) {
    detail =
      item.milesRemaining <= 0 || item.daysRemaining <= 0
        ? `Overdue by ${Math.max(-item.milesRemaining, 0).toLocaleString()} mi`
        : `${item.milesRemaining.toLocaleString()} mi or ${item.daysRemaining} days`;
  } else if (item.milesRemaining != null) {
    detail = item.milesRemaining <= 0 ? `Overdue by ${Math.abs(item.milesRemaining).toLocaleString()} mi` : `${item.milesRemaining.toLocaleString()} mi left`;
  } else if (item.daysRemaining != null) {
    detail = item.daysRemaining <= 0 ? `Overdue by ${Math.abs(item.daysRemaining)} days` : `${item.daysRemaining} days left`;
  } else if (item.lastLog) {
    detail = "Logged, no reminder set";
  }

  return (
    <Link href={`/log?vehicle=${vehicleId}&type=${item.type.id}`} className="list-row active:opacity-70">
      <div
        className="w-7 h-7 rounded-lg flex items-center justify-center shrink-0"
        style={{ background: `color-mix(in srgb, ${color} 15%, transparent)`, color }}
      >
        <Icon className="w-3.5 h-3.5" strokeWidth={2} />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-[15px] font-medium truncate">{item.type.name}</p>
        <p className="text-xs text-muted truncate">{detail}</p>
      </div>
      <span
        className="text-[11px] font-semibold px-2.5 py-1 rounded-full shrink-0"
        style={{ background: `color-mix(in srgb, ${color} 14%, transparent)`, color }}
      >
        {STATUS_LABEL[item.status]}
      </span>
      <ChevronRight className="w-3.5 h-3.5 text-muted shrink-0" strokeWidth={2.25} />
    </Link>
  );
}
