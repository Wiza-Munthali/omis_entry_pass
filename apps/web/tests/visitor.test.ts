import { describe, expect, it } from "vitest";
import {
  aboutYouSchema,
  addDays,
  localToday,
  submitErrorMessage,
  yourVisitSchema,
} from "@/lib/visitor";

describe("visitor request", () => {
  it("uses the Blantyre date, not the device's", () => {
    // 22:30 UTC on the 16th is already the 17th in CAT.
    expect(localToday(new Date("2026-10-16T22:30:00Z"))).toBe("2026-10-17");
    expect(addDays("2026-10-30", 3)).toBe("2026-11-02");
  });

  it("checks step 1 contact details", () => {
    const ok = {
      fullName: "Thoko Phiri",
      phone: "+265 884 765 432",
      email: "T@Example.com ",
      idNumber: "MW 1",
    };
    expect(aboutYouSchema.parse(ok).email).toBe("t@example.com");
    expect(aboutYouSchema.safeParse({ ...ok, phone: "abc" }).success).toBe(
      false,
    );
    expect(aboutYouSchema.safeParse({ ...ok, email: "nope" }).success).toBe(
      false,
    );
  });

  it("limits the start date to today … 14 days ahead", () => {
    const schema = yourVisitSchema("2026-10-17");
    const base = {
      hostName: "Finance",
      purpose: "meeting",
      passType: "day",
      plate: "",
    };
    expect(schema.safeParse({ ...base, startDate: "2026-10-17" }).success).toBe(
      true,
    );
    expect(schema.safeParse({ ...base, startDate: "2026-10-31" }).success).toBe(
      true,
    );
    expect(schema.safeParse({ ...base, startDate: "2026-11-01" }).success).toBe(
      false,
    );
    expect(schema.safeParse({ ...base, startDate: "2026-10-16" }).success).toBe(
      false,
    );
  });

  it("makes the plate optional but normalised", () => {
    const schema = yourVisitSchema("2026-10-17");
    const base = {
      hostName: "Finance",
      purpose: "delivery",
      passType: "week",
      startDate: "2026-10-17",
    };
    expect(schema.parse({ ...base, plate: "" }).plate).toBe("");
    expect(schema.parse({ ...base, plate: "mz 22 10" }).plate).toBe("MZ2210");
    expect(schema.safeParse({ ...base, plate: "MZ-2210" }).success).toBe(false);
  });

  it("explains rate limiting", () => {
    expect(submitErrorMessage(429)).toMatch(/wait an hour/);
  });
});
