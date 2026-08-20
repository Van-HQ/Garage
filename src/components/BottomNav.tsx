"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Home, PlusCircle, Wrench, Settings } from "lucide-react";

const TABS = [
  { href: "/", label: "Home", icon: Home },
  { href: "/log", label: "Log", icon: PlusCircle },
  { href: "/maintenance", label: "Care", icon: Wrench },
  { href: "/settings", label: "Settings", icon: Settings },
];

export default function BottomNav() {
  const pathname = usePathname();

  if (pathname.startsWith("/login")) return null;

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 flex justify-center px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))]">
      <div className="glass-pill flex items-center gap-1 rounded-full px-2 py-2">
        {TABS.map(({ href, label, icon: Icon }) => {
          const active = href === "/" ? pathname === "/" : pathname.startsWith(href);
          return (
            <Link
              key={href}
              href={href}
              className="relative flex flex-col items-center justify-center gap-0.5 rounded-full px-4 py-2 min-w-[64px] transition-colors"
            >
              {active && (
                <span className="absolute inset-0 rounded-full bg-[var(--accent)]/15" aria-hidden />
              )}
              <Icon
                className="relative w-5 h-5"
                strokeWidth={active ? 2.25 : 1.75}
                style={{ color: active ? "var(--accent)" : "var(--muted)" }}
              />
              <span
                className="relative text-[10px] font-medium"
                style={{ color: active ? "var(--accent)" : "var(--muted)" }}
              >
                {label}
              </span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
