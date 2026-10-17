/** Visits log filters, read from the URL so filtered views and exports are shareable. */
export type VisitFilters = {
  q: string;
  gate: string;
  type: "" | "staff" | "day" | "week";
  from: string; // YYYY-MM-DD (Africa/Blantyre)
  to: string;
  page: number;
};

export const VISITS_PAGE_SIZE = 25;

const DATE = /^\d{4}-\d{2}-\d{2}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function parseVisitFilters(
  sp: Record<string, string | string[] | undefined>,
  today: string,
): VisitFilters {
  const one = (k: string) => {
    const v = sp[k];
    return (Array.isArray(v) ? v[0] : v)?.trim() ?? "";
  };
  const type = one("type");
  const from = DATE.test(one("from")) ? one("from") : today;
  const to = DATE.test(one("to")) ? one("to") : from;
  return {
    q: one("q").slice(0, 80),
    gate: UUID.test(one("gate")) ? one("gate") : "",
    type: type === "staff" || type === "day" || type === "week" ? type : "",
    from: from <= to ? from : to,
    to: from <= to ? to : from,
    page: Math.max(1, Math.min(10_000, Number.parseInt(one("page"), 10) || 1)),
  };
}

/** Arguments for the search_visits RPC. */
export function searchArgs(
  f: VisitFilters,
  limit = VISITS_PAGE_SIZE,
  offset = (f.page - 1) * VISITS_PAGE_SIZE,
) {
  return {
    p_query: f.q || null,
    p_gate_id: f.gate || null,
    p_pass_type: f.type || null,
    p_from: f.from,
    p_to: f.to,
    p_limit: limit,
    p_offset: offset,
  };
}

export function filtersToQuery(f: Partial<VisitFilters>): string {
  const params = new URLSearchParams();
  for (const [k, v] of Object.entries(f)) {
    if (v !== "" && v !== undefined && v !== null && !(k === "page" && v === 1))
      params.set(k, String(v));
  }
  const s = params.toString();
  return s ? `?${s}` : "";
}
