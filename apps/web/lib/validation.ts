import { z } from "zod";

/** "bt 4521" → "BT4521", matching how the database stores plates. */
export function normalizePlate(value: string): string {
  return value.replace(/\s+/g, "").toUpperCase();
}

export function emailDomain(email: string): string {
  return email.slice(email.lastIndexOf("@") + 1).toLowerCase();
}

export function isAllowedEmail(
  email: string,
  allowedDomains: string[],
): boolean {
  const domain = emailDomain(email);
  return allowedDomains.some((d) => d.toLowerCase() === domain);
}

export const emailSchema = z.object({
  email: z
    .string()
    .trim()
    .toLowerCase()
    .pipe(z.email({ message: "Enter a valid email address." })),
});

export const codeSchema = z.object({
  code: z
    .string()
    .regex(/^\d{6}$/, { message: "Enter the 6-digit code from your email." }),
});

export const staffDetailsSchema = z
  .object({
    fullName: z
      .string()
      .trim()
      .min(2, { message: "Enter your full name." })
      .max(80, { message: "Name is too long." }),
    idNumber: z
      .string()
      .trim()
      .min(3, { message: "Enter your ID number." })
      .max(30, { message: "ID number is too long." }),
    drives: z.boolean(),
    plate: z.string().transform(normalizePlate),
  })
  .superRefine((value, ctx) => {
    if (!value.drives) return;
    if (!value.plate) {
      ctx.addIssue({
        code: "custom",
        path: ["plate"],
        message: "Enter your number plate.",
      });
    } else if (!/^[A-Z0-9]{2,12}$/.test(value.plate)) {
      ctx.addIssue({
        code: "custom",
        path: ["plate"],
        message: "Use letters and numbers only, e.g. BT 4521.",
      });
    }
  })
  .transform((value) => ({
    ...value,
    plate: value.drives ? value.plate : null,
  }));

export type StaffDetails = z.infer<typeof staffDetailsSchema>;

/** First message per field, for showing under each input. */
export function fieldErrors(error: z.ZodError): Record<string, string> {
  const out: Record<string, string> = {};
  for (const issue of error.issues) {
    const key = String(issue.path[0] ?? "form");
    out[key] ??= issue.message;
  }
  return out;
}
