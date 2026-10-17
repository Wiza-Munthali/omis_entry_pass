import Link from "next/link";
import { ChevronRight, Flag, Hourglass } from "lucide-react";
import { requireAdmin } from "@/lib/admin/auth";
import { displayPlate, formatTime, timeAgo } from "@/lib/format";
import { ActionButton } from "@/components/admin/action-button";
import { HourlyChart } from "@/components/admin/hourly-chart";
import {
  Empty,
  Initials,
  PageHeader,
  Panel,
  Pill,
  Table,
  TypePill,
} from "@/components/admin/ui";
import { checkOutVisit, resolveFlag } from "../actions";

const FLAG_LABEL: Record<string, string> = {
  exit_without_entry: "Exit without entry",
  double_entry: "Double entry",
  auto_closed: "Auto-closed at night",
  scan_invalid_pass: "Blocked pass scanned",
  approval_escalated: "Request waited too long",
  offline_conflict: "Pass changed while offline",
};

// A2 Overview: KPI row, live on site, needs attention, entries by hour.
export default async function Overview() {
  const { supabase } = await requireAdmin();
  const [
    { data: kpi },
    { data: onSite },
    { data: escalated },
    { data: flags },
  ] = await Promise.all([
    supabase.rpc("dashboard_overview"),
    supabase
      .from("on_site")
      .select(
        "visit_id, full_name, pass_type, vehicle_plate, gate_name, entry_at",
      )
      .order("entry_at", { ascending: false })
      .limit(10),
    supabase
      .from("passes")
      .select("id, created_at, people(full_name)")
      .eq("status", "pending")
      .not("escalated_at", "is", null)
      .order("created_at")
      .limit(5),
    supabase
      .from("flags")
      .select("id, type, created_at, passes(people(full_name))")
      .is("resolved_at", null)
      .order("created_at", { ascending: false })
      .limit(5),
  ]);

  const stats = [
    { label: "On site now", value: kpi?.on_site ?? 0, dash: "bg-brand" },
    {
      label: "Entries today",
      value: kpi?.entries_today ?? 0,
      dash: "bg-brand-strong",
    },
    {
      label: "Pending requests",
      value: kpi?.pending_requests ?? 0,
      dash: "bg-warning",
    },
    { label: "Open flags", value: kpi?.open_flags ?? 0, dash: "bg-danger" },
  ];

  return (
    <div className="grid gap-6">
      <PageHeader title="Overview" subtitle="Live activity at all gates" />

      <section
        aria-label="Key numbers"
        className="grid grid-cols-2 rounded-card border border-border bg-surface md:grid-cols-4"
      >
        {stats.map((s, i) => (
          <div
            key={s.label}
            className={`p-5 ${i > 0 ? "md:border-l md:border-border" : ""} ${i % 2 ? "border-l border-border md:border-l" : ""} ${i > 1 ? "border-t border-border md:border-t-0" : ""}`}
          >
            <span
              className={`block h-1 w-6 rounded-full ${s.dash}`}
              aria-hidden
            />
            <p className="mt-3 text-[2rem] leading-none font-semibold text-ink">
              {s.value}
            </p>
            <p className="mt-2 text-label text-text-muted">{s.label}</p>
          </div>
        ))}
      </section>

      <div className="grid gap-6 xl:grid-cols-[1fr_380px]">
        <Panel
          title="Live on site"
          subtitle="People on the premises now"
          actions={
            <Link
              className="text-label font-medium text-brand-strong hover:underline"
              href="/admin/visits"
            >
              Visits log
            </Link>
          }
        >
          {onSite?.length ? (
            <Table
              head={["Name", "Type", "Plate", "Gate", "Time in", ""]}
              caption="People on site"
            >
              {onSite.map((v) => (
                <tr key={v.visit_id}>
                  <td>
                    <span className="flex items-center gap-2 font-medium text-ink">
                      <Initials name={v.full_name} /> {v.full_name}
                    </span>
                  </td>
                  <td>
                    <TypePill type={v.pass_type} />
                  </td>
                  <td>
                    {v.vehicle_plate ? displayPlate(v.vehicle_plate) : "—"}
                  </td>
                  <td>{v.gate_name}</td>
                  <td>{formatTime(v.entry_at)}</td>
                  <td className="text-right">
                    <ActionButton
                      label="Check out"
                      confirm={{
                        title: `Check out ${v.full_name}?`,
                        body: "Records that they left now.",
                        action: "Check out",
                      }}
                      run={checkOutVisit.bind(null, v.visit_id)}
                    />
                  </td>
                </tr>
              ))}
            </Table>
          ) : (
            <Empty text="No one is on site right now." />
          )}
        </Panel>

        <div className="grid content-start gap-6">
          <Panel
            title="Needs attention"
            subtitle="Requests and issues waiting for an admin"
          >
            {!escalated?.length && !flags?.length ? (
              <Empty text="Nothing needs attention." />
            ) : (
              <ul className="divide-y divide-border">
                {escalated?.map((r) => (
                  <li key={r.id} className="flex items-center gap-3 py-3">
                    <span className="flex size-10 items-center justify-center rounded-full bg-warning-soft text-warning">
                      <Hourglass className="size-5" />
                    </span>
                    <Link
                      href={`/admin/requests?tab=escalated&id=${r.id}`}
                      className="min-w-0 flex-1 hover:underline"
                    >
                      <p className="truncate font-medium text-ink">
                        {
                          (r.people as unknown as { full_name: string })
                            .full_name
                        }
                      </p>
                      <p className="text-caption text-text-muted">
                        Waiting since {timeAgo(r.created_at)}
                      </p>
                    </Link>
                    <Pill tone="warning">Escalated</Pill>
                    <ChevronRight
                      className="size-4 text-text-muted"
                      aria-hidden
                    />
                  </li>
                ))}
                {flags?.map((f) => (
                  <li key={f.id} className="flex items-center gap-3 py-3">
                    <span className="flex size-10 items-center justify-center rounded-full bg-danger-soft text-danger">
                      <Flag className="size-5" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-medium text-ink">
                        {FLAG_LABEL[f.type] ?? f.type}
                      </p>
                      <p className="truncate text-caption text-text-muted">
                        {(
                          f.passes as unknown as {
                            people: { full_name: string };
                          } | null
                        )?.people.full_name ?? "—"}{" "}
                        · {timeAgo(f.created_at)}
                      </p>
                    </div>
                    <ActionButton
                      label="Resolve"
                      run={resolveFlag.bind(null, f.id)}
                    />
                  </li>
                ))}
              </ul>
            )}
          </Panel>
          <Panel title="Entries by hour" subtitle="Today, Africa/Blantyre time">
            <HourlyChart counts={kpi?.entries_by_hour ?? []} />
          </Panel>
        </div>
      </div>
    </div>
  );
}
