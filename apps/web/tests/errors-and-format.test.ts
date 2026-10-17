import { describe, expect, it } from "vitest";
import { friendlyError, GENERIC_ERROR } from "@/lib/errors";
import { displayPlate, formatDate } from "@/lib/format";

describe("friendlyError", () => {
  it("maps RPC error keys", () => {
    expect(friendlyError({ message: "pass_revoked", code: "P0001" })).toMatch(
      /revoked/,
    );
    expect(
      friendlyError({ message: "email_domain_not_allowed", code: "42501" }),
    ).toMatch(/work email/);
    expect(
      friendlyError({ message: "id_number_in_use", code: "P0001" }),
    ).toMatch(/reception/);
  });
  it("maps the auth hook's refusal and bad codes", () => {
    expect(
      friendlyError({
        message: "Use your work email address to get a staff pass.",
      }),
    ).toMatch(/work email/);
    expect(
      friendlyError({
        code: "otp_expired",
        message: "Token has expired or is invalid",
      }),
    ).toMatch(/code/);
  });
  it("never leaks unknown internals", () => {
    expect(
      friendlyError({ message: 'relation "x" does not exist', code: "42P01" }),
    ).toBe(GENERIC_ERROR);
    expect(friendlyError(null)).toBe(GENERIC_ERROR);
  });
});

describe("format", () => {
  it("shows dates in Africa/Blantyre", () => {
    // 23:30 UTC is already the next day in CAT (UTC+2).
    expect(formatDate("2027-10-16T23:30:00Z")).toBe("17 Oct 2027");
  });
  it("spaces plates for display", () => {
    expect(displayPlate("BT4521")).toBe("BT 4521");
    expect(displayPlate("GHII1")).toBe("GHII 1");
  });
});
