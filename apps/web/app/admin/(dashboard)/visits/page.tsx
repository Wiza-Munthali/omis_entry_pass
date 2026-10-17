import Link from "next/link";
import { Download, Search } from "lucide-react";
import { requireAdmin } from "@/lib/admin/auth";
import {
  filtersToQuery,
  parseVisitFilters,
  searchArgs,
  VISITS_PAGE_SIZE,
} from "@/lib/admin/visits";
import {
  displayPlate,
  formatDate,
  formatDuration,
  formatTime,
} from "@/lib/format";
import { localToday } from "@/lib/visitor";
import {
  Empty,
  Initials,
  PageHeader,
  Pagination,
  Panel,
  Pill,
  Table,
  TypePill,
} from "@/components/admin/ui";

type Row = {
  visit_id: string;
  full_name: string;
  pass_type: string;
  plate?: string;
  gate_name: string;
  entry_at: string;
  exit_at?: string;
  auto_closed?: boolean;
  recorded_offline?: boolean;
};

const control =
  "h-11 rounded-full border border-border bg-surface px-4 text-body outline-none focus-visible:border-brand focus-visible:ring-[3px] focus-visible:ring-brand/30";

// A3 Visits log: filter bar (search, gate, pass type, date range), table, CSV export.
export default async function VisitsLog({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { supabase } = await requireAdmin();
  const f = parseVisitFilters(await searchParams, localToday());
  const [{ data, error }, { data: gates }] = await Promise.all([
    supabase.rpc("search_visits", searchArgs(f)),
    supabase.from("gates").select("id, name").order("name"),
  ]);
  const rows = (data?.rows ?? []) as Row[];
  const total = (data?.total ?? 0) as number;
  const exportHref = `/admin/visits/export${filtersToQuery({ ...f, page: 1 })}`;

  return (
    <div className="grid gap-6">
      <PageHeader
        title="Visits log"
        subtitle="Every entry and exit across all gates"
        actions={
          <a
            href={exportHref}
            className="inline-flex h-11 items-center gap-2 rounded-full bg-brand px-5 font-semibold text-ink hover:bg-brand-strong hover:text-surface"
            download
          >
            <Download className="size-5" /> Export CSV
          </a>
        }
      />

      <form
        className="flex flex-wrap items-end gap-3 rounded-card border border-border bg-surface p-4"
        role="search"
      >
        <label className="relative min-w-60 flex-1">
          <span className="sr-only">Search by name, plate or ID number</span>
          <Search className="pointer-events-none absolute top-1/2 left-4 size-5 -translate-y-1/2 text-text-muted" />
          <input
            name="q"
            defaultValue={f.q}
            placeholder="Search by name, plate or ID…"
            className={`${control} w-full pl-11`}
          />
        </label>
        <label>
          <span className="sr-only">Gate</span>
          <select name="gate" defaultValue={f.gate} className={control}>
            <option value="">All gates</option>
            {gates?.map((g) => (
              <option key={g.id} value={g.id}>
                {g.name}
              </option>
            ))}
          </select>
        </label>
        <label>
          <span className="sr-only">Pass type</span>
          <select name="type" defaultValue={f.type} className={control}>
            <option value="">All pass types</option>
            <option value="staff">Staff</option>
            <option value="day">Visitor · day</option>
            <option value="week">Visitor · week</option>
          </select>
        </label>
        <label className="grid gap-1 text-caption text-text-muted">
          From
          <input
            type="date"
            name="from"
            defaultValue={f.from}
            className={control}
          />
        </label>
        <label className="grid gap-1 text-caption text-text-muted">
          To
          <input
            type="date"
            name="to"
            defaultValue={f.to}
            className={control}
          />
        </label>
        <button className="h-11 rounded-full bg-ink px-5 font-semibold text-brand hover:bg-ink-2">
          Apply
        </button>
        <Link
          href="/admin/visits"
          className="h-11 content-center rounded-full px-3 font-medium text-text-muted hover:text-ink"
        >
          Reset
        </Link>
      </form>

      <Panel>
        {error ? (
          <p role="alert" className="text-danger">
            Could not load visits: {error.message}
          </p>
        ) : rows.length === 0 ? (
          <Empty
            text={`No visits ${f.from === f.to ? `on ${formatDate(`${f.from}T12:00:00Z`)}` : "in these dates"} match.`}
          />
        ) : (
          <>
            <Table
              head={[
                "Person",
                "Type",
                "Plate",
                "Gate",
                "Date",
                "Time in",
                "Time out",
                "Duration",
                "Status",
              ]}
              caption="Visits"
            >
              {rows.map((v) => (
                <tr key={v.visit_id}>
                  <td>
                    <span className="flex items-center gap-2 font-medium text-ink">
                      <Initials name={v.full_name} /> {v.full_name}
                    </span>
                  </td>
                  <td>
                    <TypePill type={v.pass_type} />
                  </td>
                  <td>{v.plate ? displayPlate(v.plate) : "—"}</td>
                  <td>{v.gate_name}</td>
                  <td className="whitespace-nowrap">
                    {formatDate(v.entry_at)}
                  </td>
                  <td>{formatTime(v.entry_at)}</td>
                  <td>{v.exit_at ? formatTime(v.exit_at) : "—"}</td>
                  <td className="whitespace-nowrap">
                    {v.exit_at ? formatDuration(v.entry_at, v.exit_at) : "—"}
                  </td>
                  <td>
                    {!v.exit_at ? (
                      <Pill tone="success">On site</Pill>
                    ) : v.auto_closed ? (
                      <Pill tone="warning">Auto-closed</Pill>
                    ) : (
                      <Pill tone="neutral">Checked out</Pill>
                    )}
                    {v.recorded_offline && (
                      <span className="ml-2 text-caption text-text-muted">
                        offline
                      </span>
                    )}
                  </td>
                </tr>
              ))}
            </Table>
            <Pagination
              page={f.page}
              pageSize={VISITS_PAGE_SIZE}
              total={total}
              href={(p) => `/admin/visits${filtersToQuery({ ...f, page: p })}`}
            />
          </>
        )}
      </Panel>
    </div>
  );
}
