import { describe, expect, it } from "vitest";
import {
  codeSchema,
  emailSchema,
  isAllowedEmail,
  normalizePlate,
  staffDetailsSchema,
} from "@/lib/validation";

describe("email", () => {
  it("trims and lower-cases", () => {
    expect(emailSchema.parse({ email: "  Wiza@GHII.test " })).toEqual({
      email: "wiza@ghii.test",
    });
  });
  it("rejects non-emails", () => {
    expect(emailSchema.safeParse({ email: "wiza" }).success).toBe(false);
  });
  it("checks the domain exactly, ignoring case", () => {
    expect(isAllowedEmail("a@ghii.test", ["GHII.test"])).toBe(true);
    expect(isAllowedEmail("a@ghii.test.evil.com", ["ghii.test"])).toBe(false);
    expect(isAllowedEmail("a@sub.ghii.test", ["ghii.test"])).toBe(false);
    expect(isAllowedEmail("a@ghii.test", [])).toBe(false);
  });
});

describe("code", () => {
  it("needs exactly six digits", () => {
    expect(codeSchema.safeParse({ code: "123456" }).success).toBe(true);
    expect(codeSchema.safeParse({ code: "12345" }).success).toBe(false);
    expect(codeSchema.safeParse({ code: "12345a" }).success).toBe(false);
  });
});

describe("staff details", () => {
  const base = {
    fullName: "Chikondi Banda",
    idNumber: "MW 1001",
    drives: false,
    plate: "",
  };

  it("accepts details without a vehicle and drops any plate", () => {
    expect(staffDetailsSchema.parse({ ...base, plate: "BT 1" })).toMatchObject({
      plate: null,
      drives: false,
    });
  });
  it("requires and normalises the plate when driving", () => {
    expect(
      staffDetailsSchema.safeParse({ ...base, drives: true }).success,
    ).toBe(false);
    expect(
      staffDetailsSchema.parse({ ...base, drives: true, plate: "bt 4521" })
        .plate,
    ).toBe("BT4521");
  });
  it("rejects plates with symbols", () => {
    expect(
      staffDetailsSchema.safeParse({ ...base, drives: true, plate: "BT-4521" })
        .success,
    ).toBe(false);
  });
  it("requires a name and ID number", () => {
    expect(
      staffDetailsSchema.safeParse({ ...base, fullName: " " }).success,
    ).toBe(false);
    expect(
      staffDetailsSchema.safeParse({ ...base, idNumber: "" }).success,
    ).toBe(false);
  });
  it("normalises plates like the database", () => {
    expect(normalizePlate(" mz 22 10 ")).toBe("MZ2210");
  });
});
