import Link from "next/link";
import { requireAdmin } from "@/lib/admin/auth";
import { cn } from "@/lib/utils";
import { formatDateTime } from "@/lib/format";
import { ActionButton } from "@/components/admin/action-button";
import { Empty, PageHeader, Panel, Pill, Table } from "@/components/admin/ui";
import { resolveFlag } from "../../actions";

const TYPES = {
  scan_invalid_pass: { label: "Blocked pass scanned", tone: "danger" },
  offline_conflict: { label: "Changed while offline", tone: "danger" },
  approval_escalated: { label: "Request waited", tone: "warning" },
  auto_closed: { label: "Auto-closed", tone: "warning" },
  double_entry: { label: "Double entry", tone: "info" },
  exit_without_entry: { label: "Exit without entry", tone: "info" },
} as const;

function describe(type: string, d: Record<string, unknown>): string {
  if (type === "scan_invalid_pass" || type === "offline_conflict")
    return `Pass ${String(d.result ?? "").replaceAll("_", " ")}`;
  if (type === "approval_escalated")
    return `Waited ${d.waited_minutes ?? "?"} min for approval`;
  if (type === "auto_closed")
    return "Still inside at closing time; checked out automatically";
  return "";
}

// A10 Flags: type pill, person, details, time, Resolve; filter by type.
export default async function Flags({
  searchParams,
}: {
  searchParams: Promise<{ type?: string; resolved?: string }>;
}) {
  const sp = await searchParams;
  const type = sp.type && sp.type in TYPES ? sp.type : "";
  const showResolved = sp.resolved === "1";
  const { supabase } = await requireAdmin();
  let q = supabase
    .from("flags")
    .select(
      "id, type, details, created_at, resolved_at, passes(people(full_name))",
    );
  if (type) q = q.eq("type", type);
  if (!showResolved) q = q.is("resolved_at", null);
  const { data: flags } = await q
    .order("created_at", { ascending: false })
    .limit(200);

  const link = (t: string, r = showResolved) =>
    `/admin/flags?${new URLSearchParams({ ...(t ? { type: t } : {}), ...(r ? { resolved: "1" } : {}) })}`;

  return (
    <div className="grid gap-6">
      <PageHeader
        title="Flags"
        subtitle="Things the system noticed that an admin should look at"
      />
      <div className="flex flex-wrap items-center gap-2">
        {[
          ["", "All"],
          ...Object.entries(TYPES).map(([k, v]) => [k, v.label]),
        ].map(([k, label]) => (
          <Link
            key={k}
            href={link(k)}
            aria-current={k === type ? "page" : undefined}
            className={cn(
              "rounded-full border border-border px-4 py-2 text-label font-medium",
              k === type
                ? "bg-ink text-brand"
                : "bg-surface hover:bg-surface-2",
            )}
          >
            {label}
          </Link>
        ))}
        <Link
          href={link(type, !showResolved)}
          className="ml-auto text-label font-medium text-brand-strong hover:underline"
        >
          {showResolved ? "Hide resolved" : "Show resolved"}
        </Link>
      </div>
      <Panel>
        {!flags?.length ? (
          <Empty text="No open flags. All clear." />
        ) : (
          <Table
            head={["Type", "Person", "Details", "Time", ""]}
            caption="Flags"
          >
            {flags.map((f) => {
              const t = TYPES[f.type as keyof typeof TYPES];
              return (
                <tr key={f.id}>
                  <td>
                    <Pill tone={t?.tone ?? "neutral"}>
                      {t?.label ?? f.type}
                    </Pill>
                  </td>
                  <td className="font-medium text-ink">
                    {(
                      f.passes as unknown as {
                        people: { full_name: string };
                      } | null
                    )?.people.full_name ?? "—"}
                  </td>
                  <td className="text-text-muted">
                    {describe(
                      f.type,
                      (f.details ?? {}) as Record<string, unknown>,
                    )}
                  </td>
                  <td className="whitespace-nowrap">
                    {formatDateTime(f.created_at)}
                  </td>
                  <td className="text-right">
                    {f.resolved_at ? (
                      <span className="text-caption text-text-muted">
                        Resolved
                      </span>
                    ) : (
                      <ActionButton
                        label="Resolve"
                        run={resolveFlag.bind(null, f.id)}
                      />
                    )}
                  </td>
                </tr>
              );
            })}
          </Table>
        )}
      </Panel>
    </div>
  );
}
