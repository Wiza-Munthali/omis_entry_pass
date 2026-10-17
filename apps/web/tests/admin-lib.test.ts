import { describe, expect, it } from "vitest";
import { csvField, toCsv } from "@/lib/admin/csv";
import {
  filtersToQuery,
  parseVisitFilters,
  searchArgs,
} from "@/lib/admin/visits";
import { formatDuration, timeAgo } from "@/lib/format";

describe("CSV", () => {
  it("quotes commas, quotes and newlines", () => {
    expect(csvField('Banda, "CB"')).toBe('"Banda, ""CB"""');
    expect(csvField("two\nlines")).toBe('"two\nlines"');
    expect(csvField(null)).toBe("");
  });
  it("neutralises spreadsheet formulas", () => {
    expect(csvField("=HYPERLINK(1)")).toBe("'=HYPERLINK(1)");
    expect(csvField("+265 991")).toBe("'+265 991");
    expect(csvField("-1")).toBe("'-1");
  });
  it("builds rows with a header and CRLF", () => {
    expect(toCsv(["a", "b"], [[1, "x"]])).toBe("a,b\r\n1,x\r\n");
  });
});

describe("visit filters", () => {
  const today = "2026-10-17";
  it("defaults to today", () => {
    expect(parseVisitFilters({}, today)).toEqual({
      q: "",
      gate: "",
      type: "",
      from: today,
      to: today,
      page: 1,
    });
  });
  it("ignores junk and swaps reversed dates", () => {
    const f = parseVisitFilters(
      {
        q: " bt 45 ",
        gate: "not-a-uuid",
        type: "admin",
        from: "2026-10-20",
        to: "2026-10-01",
        page: "-3",
      },
      today,
    );
    expect(f).toEqual({
      q: "bt 45",
      gate: "",
      type: "",
      from: "2026-10-01",
      to: "2026-10-20",
      page: 1,
    });
  });
  it("maps to search_visits arguments with paging", () => {
    const f = parseVisitFilters({ type: "week", page: "3" }, today);
    expect(searchArgs(f)).toMatchObject({
      p_pass_type: "week",
      p_from: today,
      p_limit: 25,
      p_offset: 50,
      p_query: null,
    });
  });
  it("round-trips to a query string without defaults", () => {
    expect(filtersToQuery({ q: "", type: "staff", page: 1 })).toBe(
      "?type=staff",
    );
  });
});

describe("format", () => {
  it("durations and ages", () => {
    expect(formatDuration("2026-10-17T08:00:00Z", "2026-10-17T08:47:00Z")).toBe(
      "47 min",
    );
    expect(formatDuration("2026-10-17T08:00:00Z", "2026-10-17T09:35:00Z")).toBe(
      "1 h 35 min",
    );
    expect(
      timeAgo("2026-10-17T08:00:00Z", new Date("2026-10-17T08:04:30Z")),
    ).toBe("4 min ago");
  });
});
