import { NextResponse, type NextRequest } from "next/server";
import { requireAdmin } from "@/lib/admin/auth";
import { toCsv } from "@/lib/admin/csv";
import { parseVisitFilters, searchArgs } from "@/lib/admin/visits";
import { formatDate, formatDuration, formatTime } from "@/lib/format";
import { localToday } from "@/lib/visitor";

const MAX_ROWS = 50_000;

/** CSV of the visits log with the same filters as the page (times in Africa/Blantyre). */
export async function GET(request: NextRequest) {
  const { supabase } = await requireAdmin();
  const f = parseVisitFilters(
    Object.fromEntries(request.nextUrl.searchParams),
    localToday(),
  );
  const { data, error } = await supabase.rpc(
    "search_visits",
    searchArgs(f, MAX_ROWS, 0),
  );
  if (error)
    return NextResponse.json({ error: error.message }, { status: 500 });

  type Row = {
    full_name: string;
    pass_type: string;
    plate?: string;
    gate_name: string;
    entry_at: string;
    exit_at?: string;
    auto_closed?: boolean;
    recorded_offline?: boolean;
  };
  const rows = ((data?.rows ?? []) as Row[]).map((v) => [
    v.full_name,
    v.pass_type,
    v.plate ?? "",
    v.gate_name,
    formatDate(v.entry_at),
    formatTime(v.entry_at),
    v.exit_at ? formatDate(v.exit_at) : "",
    v.exit_at ? formatTime(v.exit_at) : "",
    v.exit_at ? formatDuration(v.entry_at, v.exit_at) : "",
    !v.exit_at ? "On site" : v.auto_closed ? "Auto-closed" : "Checked out",
    v.recorded_offline ? "yes" : "no",
  ]);
  const csv = toCsv(
    [
      "Person",
      "Pass type",
      "Plate",
      "Gate",
      "Date in",
      "Time in",
      "Date out",
      "Time out",
      "Duration",
      "Status",
      "Recorded offline",
    ],
    rows,
  );
  const name =
    f.from === f.to
      ? `visits-${f.from}.csv`
      : `visits-${f.from}-to-${f.to}.csv`;
  return new NextResponse(csv, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="${name}"`,
      "Cache-Control": "no-store",
    },
  });
}
