import { describe, expect, it } from "vitest";
import {
  formatValidity,
  renderPassEmail,
  renderRejectionEmail,
} from "../../../supabase/functions/_shared/pass-email.ts";
import { formatValidity as webFormatValidity } from "@/lib/format";

// A week pass from 18 Oct (CAT midnight = 22:00 UTC the day before) to 25 Oct midnight.
const from = "2026-10-17T22:00:00Z";
const until = "2026-10-24T22:00:00Z";

describe("visitor validity", () => {
  it("shows the last valid day, not the following midnight", () => {
    expect(formatValidity("week", from, until)).toBe("18 Oct – 24 Oct 2026");
    expect(formatValidity("day", from, "2026-10-18T22:00:00Z")).toBe(
      "18 Oct 2026",
    );
  });
  it("matches what the status page shows", () => {
    expect(webFormatValidity("week", from, until)).toBe(
      formatValidity("week", from, until),
    );
    expect(webFormatValidity("day", from, "2026-10-18T22:00:00Z")).toBe(
      "18 Oct 2026",
    );
  });
});

describe("visitor approved email", () => {
  const email = renderPassEmail({
    fullName: "Thoko Phiri",
    passType: "week",
    validFrom: from,
    validUntil: until,
    hostName: "Finance <office>",
    passUrl: "https://entry.example/r/abc",
    plate: "MZ2210",
  });

  it("names the visit, dates and plate", () => {
    expect(email.subject).toMatch(/approved/);
    expect(email.html).toContain("One-week visitor");
    expect(email.html).toContain("18 Oct – 24 Oct 2026");
    expect(email.html).toContain("Finance &lt;office&gt;");
    expect(email.html).toContain("MZ 2210");
  });
  it("links to the status page and gives gate instructions", () => {
    expect(email.html).toContain('href="https://entry.example/r/abc"');
    expect(email.text).toMatch(/guard when you arrive/);
  });
});

describe("rejection email", () => {
  const email = renderRejectionEmail({
    fullName: "Chisomo Gondwe",
    reason: "Host is away <today>",
    hostName: "Director's office",
    statusUrl: "https://entry.example/r/xyz",
  });

  it("gives the escaped reason and a way back", () => {
    expect(email.subject).toMatch(/not approved/);
    expect(email.html).toContain("Host is away &lt;today&gt;");
    expect(email.html).toContain("Director&#39;s office");
    expect(email.html).toContain('href="https://entry.example/r/xyz"');
    expect(email.text).toContain("Reason: Host is away <today>");
  });
  it("has no QR", () => {
    expect(email.html).not.toContain("cid:");
  });
});
