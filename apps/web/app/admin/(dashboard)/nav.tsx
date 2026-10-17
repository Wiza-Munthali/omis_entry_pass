"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  DoorOpen,
  Flag,
  IdCard,
  Inbox,
  LayoutDashboard,
  List,
  Settings,
  Users,
} from "lucide-react";
import { cn } from "@/lib/utils";

const MAIN = [
  { href: "/admin", label: "Overview", icon: LayoutDashboard },
  { href: "/admin/visits", label: "Visits", icon: List },
  { href: "/admin/requests", label: "Requests", icon: Inbox, badge: "pending" },
  { href: "/admin/passes", label: "Passes", icon: IdCard },
  { href: "/admin/flags", label: "Flags", icon: Flag, badge: "flags" },
] as const;
const MANAGE = [
  { href: "/admin/users", label: "Users", icon: Users },
  { href: "/admin/gates", label: "Gates", icon: DoorOpen },
  { href: "/admin/settings", label: "Settings", icon: Settings },
] as const;

/** Sidebar menu (spec): Overview · Visits · Requests (badge) · Passes · Flags (badge); Manage: Users · Gates · Settings. */
export function Nav({ pending, flags }: { pending: number; flags: number }) {
  const path = usePathname();
  const counts = { pending, flags };
  const item = (l: {
    href: string;
    label: string;
    icon: React.ComponentType<{ className?: string }>;
    badge?: "pending" | "flags";
  }) => {
    const active =
      l.href === "/admin" ? path === "/admin" : path.startsWith(l.href);
    const n = l.badge ? counts[l.badge] : 0;
    return (
      <Link
        key={l.href}
        href={l.href}
        aria-current={active ? "page" : undefined}
        className={cn(
          "flex items-center gap-3 rounded-full px-4 py-2.5 text-body font-medium",
          active
            ? "bg-brand-soft text-brand-strong"
            : "text-text hover:bg-surface-2",
        )}
      >
        <l.icon className="size-5" />
        <span className="flex-1">{l.label}</span>
        {n > 0 && (
          <span
            className="rounded-full bg-danger px-2 text-caption font-semibold text-surface"
            aria-label={`${n} open`}
          >
            {n}
          </span>
        )}
      </Link>
    );
  };
  return (
    <nav aria-label="Admin" className="grid gap-1">
      {MAIN.map(item)}
      <p className="mt-6 mb-1 px-4 text-caption font-semibold tracking-wide text-text-muted uppercase">
        Manage
      </p>
      {MANAGE.map(item)}
    </nav>
  );
}
