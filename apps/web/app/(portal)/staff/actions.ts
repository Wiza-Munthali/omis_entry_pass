"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { friendlyError } from "@/lib/errors";
import {
  codeSchema,
  emailSchema,
  fieldErrors,
  isAllowedEmail,
  staffDetailsSchema,
} from "@/lib/validation";

// The address the code was sent to, kept in an httpOnly cookie rather than the URL.
const OTP_EMAIL_COOKIE = "otp_email";

export type FormState = {
  error?: string;
  fields?: Record<string, string>;
  values?: Record<string, string | boolean>;
  message?: string;
};

async function requestCode(email: string): Promise<string | null> {
  const supabase = await createClient();
  const { data: config } = await supabase.rpc("portal_config");
  const domains: string[] = config?.allowed_email_domains ?? [];
  if (!isAllowedEmail(email, domains)) {
    return domains.length
      ? `Use your work email (${domains.map((d) => `@${d}`).join(" or ")}).`
      : "Staff sign-in is not set up yet. Please contact reception.";
  }

  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: { shouldCreateUser: true },
  });
  return error ? friendlyError(error) : null;
}

/** P2: send a 6-digit code to a work email address. */
export async function sendCode(
  _prev: FormState,
  formData: FormData,
): Promise<FormState> {
  const raw = String(formData.get("email") ?? "");
  const parsed = emailSchema.safeParse({ email: raw });
  if (!parsed.success)
    return { fields: fieldErrors(parsed.error), values: { email: raw } };

  const error = await requestCode(parsed.data.email);
  if (error) return { fields: { email: error }, values: { email: raw } };

  (await cookies()).set(OTP_EMAIL_COOKIE, parsed.data.email, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/staff",
    maxAge: 60 * 60,
  });
  redirect("/staff/verify");
}

/** P3: send the code again. */
export async function resendCode(): Promise<FormState> {
  const email = (await cookies()).get(OTP_EMAIL_COOKIE)?.value;
  if (!email) redirect("/staff");
  const error = await requestCode(email);
  return error ? { error } : { message: "A new code is on its way." };
}

/** P3: check the code, then go to the pass (or the details form for new staff). */
export async function verifyCode(
  _prev: FormState,
  formData: FormData,
): Promise<FormState> {
  const cookieStore = await cookies();
  const email = cookieStore.get(OTP_EMAIL_COOKIE)?.value;
  if (!email) redirect("/staff");

  const parsed = codeSchema.safeParse({
    code: String(formData.get("code") ?? ""),
  });
  if (!parsed.success) return { error: fieldErrors(parsed.error).code };

  const supabase = await createClient();
  const { error } = await supabase.auth.verifyOtp({
    email,
    token: parsed.data.code,
    type: "email",
  });
  if (error)
    return {
      error: friendlyError({ ...error, code: error.code ?? "otp_expired" }),
    };

  cookieStore.delete({ name: OTP_EMAIL_COOKIE, path: "/staff" });

  const { data: pass } = await supabase
    .from("passes")
    .select("id")
    .eq("type", "staff")
    .limit(1)
    .maybeSingle();
  redirect(pass ? "/pass" : "/staff/details");
}

/** P4: save details, issue (or update) the staff pass and email it. */
export async function saveDetails(
  _prev: FormState,
  formData: FormData,
): Promise<FormState> {
  const values = {
    fullName: String(formData.get("fullName") ?? ""),
    idNumber: String(formData.get("idNumber") ?? ""),
    drives: formData.get("drives") === "on",
    plate: String(formData.get("plate") ?? ""),
  };
  const parsed = staffDetailsSchema.safeParse(values);
  if (!parsed.success) return { fields: fieldErrors(parsed.error), values };

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/staff");

  const { error } = await supabase.rpc("register_staff_pass", {
    p_full_name: parsed.data.fullName,
    p_id_number: parsed.data.idNumber,
    p_plate: parsed.data.plate,
  });
  if (error) return { error: friendlyError(error), values };

  const { error: emailError } = await supabase.functions.invoke(
    "send-pass-email",
    { method: "POST" },
  );
  redirect(emailError ? "/pass?emailed=0" : "/pass?emailed=1");
}

/** P5: "Email me my pass". */
export async function emailPass(): Promise<FormState> {
  const supabase = await createClient();
  const { error } = await supabase.functions.invoke("send-pass-email", {
    method: "POST",
  });
  if (error)
    return {
      error: "We couldn't send the email. Please try again in a moment.",
    };
  return { message: "Sent. Check your inbox." };
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/");
}
