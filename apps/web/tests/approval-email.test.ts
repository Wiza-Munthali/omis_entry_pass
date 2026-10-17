import { describe, expect, it } from "vitest";
import { renderApprovalRequestEmail } from "../../../supabase/functions/_shared/pass-email.ts";

const base = {
  fullName: "Tiyamike <Banda>",
  passType: "day" as const,
  hostName: "ICT unit",
  requestedAt: "2026-10-17T08:42:00Z",
  validFrom: "2026-10-16T22:00:00Z",
  validUntil: "2026-10-17T22:00:00Z",
};

describe("approver emails", () => {
  it("new gate request tells reception the visitor is waiting at the gate", () => {
    const email = renderApprovalRequestEmail({
      ...base,
      source: "gate",
      requestedBy: "Yamikani Phiri",
    });
    expect(email.subject).toBe("New visitor request: Tiyamike <Banda>");
    expect(email.html).toContain("Tiyamike &lt;Banda&gt;");
    expect(email.html).toContain("A visitor is waiting at the gate.");
    expect(email.html).toContain("registered by Yamikani Phiri");
    expect(email.html).toContain("10:42");
    expect(email.html).toContain("One-day visitor, 17 Oct 2026");
    expect(email.text).toContain("Approvals");
  });

  it("escalation says how long it has waited", () => {
    const email = renderApprovalRequestEmail({
      ...base,
      source: "web",
      escalatedMinutes: 6,
    });
    expect(email.subject).toBe("Waiting 6 min for approval: Tiyamike <Banda>");
    expect(email.html).toContain("No one has approved this request yet.");
    expect(email.html).toContain("Online request");
  });
});
