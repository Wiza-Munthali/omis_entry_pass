import Image from "next/image";
import { LogOut } from "lucide-react";
import { requireAdmin } from "@/lib/admin/auth";
import { Initials } from "@/components/admin/ui";
import { adminSignOut } from "../actions";
import { Nav } from "./nav";

export const dynamic = "force-dynamic";
export const metadata = { title: "OMIS Entry admin", robots: { index: false } };

// Desktop dashboard shell: white sidebar (logo, menu, signed-in user), content on the off-white background.
export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const { supabase, admin } = await requireAdmin();
  const [{ count: pending }, { count: flags }] = await Promise.all([
    supabase
      .from("passes")
      .select("id", { count: "exact", head: true })
      .eq("status", "pending")
      .in("type", ["day", "week"]),
    supabase
      .from("flags")
      .select("id", { count: "exact", head: true })
      .is("resolved_at", null),
  ]);
  const name = admin.full_name ?? admin.email;

  return (
    <div className="min-h-dvh lg:grid lg:grid-cols-[256px_1fr]">
      <aside className="flex flex-col gap-6 border-b border-border bg-surface p-5 lg:sticky lg:top-0 lg:h-dvh lg:border-r lg:border-b-0">
        <div className="flex items-center gap-3 px-2">
          <Image src="/logo.png" alt="GHII" width={44} height={44} />
          <span className="text-title font-semibold text-ink">OMIS Entry</span>
        </div>
        <Nav pending={pending ?? 0} flags={flags ?? 0} />
        <div className="mt-auto flex items-center gap-3 rounded-card bg-surface-2 p-3">
          <Initials name={name} />
          <div className="min-w-0 flex-1">
            <p className="truncate text-label font-semibold text-ink">{name}</p>
            <p className="truncate text-caption text-text-muted">
              {admin.email}
            </p>
          </div>
          <form action={adminSignOut}>
            <button
              aria-label="Sign out"
              title="Sign out"
              className="rounded-full p-2 text-text-muted hover:bg-surface hover:text-ink"
            >
              <LogOut className="size-4" />
            </button>
          </form>
        </div>
      </aside>
      <main className="min-w-0 px-4 py-6 sm:px-8 lg:py-8">{children}</main>
    </div>
  );
}
