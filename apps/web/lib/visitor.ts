import { z } from "zod";
import { normalizePlate } from "./validation";

export const PURPOSES = [
  { value: "meeting", label: "Meeting" },
  { value: "delivery", label: "Delivery" },
  { value: "contractor", label: "Contractor work" },
  { value: "interview", label: "Interview" },
  { value: "other", label: "Other" },
] as const;

export const PASS_TYPES = [
  { value: "day", label: "One day", hint: "Valid for the start date only" },
  { value: "week", label: "One week", hint: "Valid for 7 days" },
] as const;

export const MAX_DAYS_AHEAD = 14;

/** Today's date (YYYY-MM-DD) in Africa/Blantyre, whatever the device's time zone. */
export function localToday(now = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Blantyre",
  }).format(now);
}

export function addDays(isoDate: string, days: number): string {
  const d = new Date(`${isoDate}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

export const aboutYouSchema = z.object({
  fullName: z
    .string()
    .trim()
    .min(2, { message: "Enter your full name." })
    .max(80),
  phone: z
    .string()
    .trim()
    .regex(/^\+?[\d\s()-]{8,20}$/, {
      message: "Enter a phone number, e.g. +265 991 234 567.",
    }),
  email: z
    .string()
    .trim()
    .toLowerCase()
    .pipe(z.email({ message: "Enter a valid email address." })),
  idNumber: z
    .string()
    .trim()
    .min(3, { message: "Enter your ID number." })
    .max(30),
});

export function yourVisitSchema(today: string) {
  return z.object({
    hostName: z
      .string()
      .trim()
      .min(2, { message: "Who are you visiting?" })
      .max(80),
    purpose: z.enum(PURPOSES.map((p) => p.value) as [string, ...string[]], {
      message: "Choose the purpose of your visit.",
    }),
    passType: z.enum(["day", "week"], { message: "Choose a pass type." }),
    startDate: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/, { message: "Choose a start date." })
      .refine((d) => d >= today && d <= addDays(today, MAX_DAYS_AHEAD), {
        message: `Choose a date from today to ${MAX_DAYS_AHEAD} days ahead.`,
      }),
    plate: z
      .string()
      .transform(normalizePlate)
      .refine((p) => p === "" || /^[A-Z0-9]{2,12}$/.test(p), {
        message: "Use letters and numbers only, e.g. BT 4521.",
      }),
  });
}

export type VisitorRequest = z.infer<typeof aboutYouSchema> &
  z.infer<ReturnType<typeof yourVisitSchema>>;

/** Messages for the submit-visitor-request function's responses. */
export function submitErrorMessage(status: number, error?: string): string {
  if (status === 429 || error === "rate_limited")
    return "Too many requests from this phone or network. Please wait an hour, or ask the guard at the gate.";
  if (status === 400)
    return "Some details need fixing. Check the highlighted fields.";
  return "We couldn't send your request. Check your connection and try again.";
}
