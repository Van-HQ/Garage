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
    <nav className="fixed bottom-0 left-0 right-0 z-50 flex justify-center px-3.5 pb-[max(0.75rem,env(safe-area-inset-bottom))]">
      <div className="glass-pill flex items-center gap-1 rounded-full p-1.5">
        {TABS.map(({ href, label, icon: Icon }) => {
          const active = href === "/" ? pathname === "/" : pathname.startsWith(href);
          return (
            <Link
              key={href}
              href={href}
              className="flex items-center justify-center h-[42px] rounded-full transition-all duration-200"
              style={
                active
                  ? {
                      width: "auto",
                      padding: "0 16px 0 12px",
                      gap: "7px",
                      background: "var(--nav-active-bg)",
                      color: "var(--nav-active-fg)",
                      boxShadow: "0 1px 0 rgba(255,255,255,0.5) inset, 0 6px 14px -6px rgba(0,0,0,0.35)",
                    }
                  : { width: "42px", color: "var(--muted)" }
              }
            >
              <Icon className="w-[18px] h-[18px] shrink-0" strokeWidth={active ? 2.3 : 2} />
              {active && <span className="text-sm font-bold whitespace-nowrap">{label}</span>}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
