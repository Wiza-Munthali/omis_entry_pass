"use server";

import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { requireAdmin } from "@/lib/admin/auth";
import { friendlyError } from "@/lib/errors";
import { createClient } from "@/lib/supabase/server";

export type ActionState = { error?: string; message?: string };

const OTP_COOKIE = "admin_otp_email";
const ok = (message: string): ActionState => ({ message });
const fail = (error: string): ActionState => ({ error });

// ---------------------------------------------------------------------------
// A1 Sign in (email code, admins only)
// ---------------------------------------------------------------------------
export async function adminSendCode(
  _: ActionState,
  form: FormData,
): Promise<ActionState> {
  const email = String(form.get("email") ?? "")
    .trim()
    .toLowerCase();
  if (!z.email().safeParse(email).success)
    return fail("Enter your email address.");
  const supabase = await createClient();
  // Accounts are created by admins; the dashboard never creates one.
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: { shouldCreateUser: false },
  });
  if (error)
    return fail(
      "We couldn't send a code to that address. Check it, or ask another admin to invite you.",
    );
  (await cookies()).set(OTP_COOKIE, email, {
    httpOnly: true,
    sameSite: "lax",
    path: "/admin",
    maxAge: 3600,
  });
  return ok("sent");
}

export async function adminVerifyCode(
  _: ActionState,
  form: FormData,
): Promise<ActionState> {
  const jar = await cookies();
  const email = jar.get(OTP_COOKIE)?.value;
  if (!email) return fail("Start again: enter your email.");
  const code = String(form.get("code") ?? "");
  if (!/^\d{6}$/.test(code))
    return fail("Enter the 6-digit code from your email.");
  const supabase = await createClient();
  const { error } = await supabase.auth.verifyOtp({
    email,
    token: code,
    type: "email",
  });
  if (error)
    return fail(friendlyError({ ...error, code: error.code ?? "otp_expired" }));
  jar.delete({ name: OTP_COOKIE, path: "/admin" });
  redirect("/admin");
}

export async function adminSignOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/admin/sign-in");
}

// ---------------------------------------------------------------------------
// Visits and requests
// ---------------------------------------------------------------------------
export async function checkOutVisit(visitId: string): Promise<ActionState> {
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc("check_out", {
    p_visit_id: visitId,
    p_client_event_id: crypto.randomUUID(),
  });
  if (error) return fail(friendlyError(error));
  revalidatePath("/admin", "layout");
  return ok("Checked out.");
}

export async function decideRequest(
  passId: string,
  approve: boolean,
  reason?: string,
): Promise<ActionState> {
  const { supabase } = await requireAdmin();
  if (!approve && !reason?.trim()) return fail("Give a reason for rejecting.");
  const { data, error } = await supabase.rpc("decide_request", {
    p_pass_id: passId,
    p_decision: approve ? "approve" : "reject",
    p_reason: reason?.trim() || null,
  });
  if (error)
    return fail(
      error.message === "request_expired"
        ? "This request's dates have passed. Reject it instead."
        : friendlyError(error),
    );
  revalidatePath("/admin", "layout");
  if (data?.result === "already_decided") {
    return fail(
      `Already ${data.status} by ${data.decided_by_name ?? "someone else"}.`,
    );
  }
  return ok(approve ? "Approved." : "Rejected.");
}

// ---------------------------------------------------------------------------
// A6 Passes
// ---------------------------------------------------------------------------
export async function revokePass(
  passId: string,
  reason: string,
): Promise<ActionState> {
  const { supabase } = await requireAdmin();
  const { data, error } = await supabase.rpc("revoke_pass", {
    p_pass_id: passId,
    p_reason: reason.trim() || null,
  });
  if (error) return fail(friendlyError(error));
  revalidatePath("/admin/passes");
  return data?.result === "revoked"
    ? ok("Pass revoked. The holder has been emailed.")
    : fail(`Not changed: the pass is ${data?.status}.`);
}

export async function extendPass(
  passId: string,
  days: number,
): Promise<ActionState> {
  const { supabase } = await requireAdmin();
  const { error } = await supabase.rpc("extend_pass", {
    p_pass_id: passId,
    p_days: days,
  });
  if (error) {
    return fail(
      error.message === "pass_not_extendable"
        ? "Revoked or pending passes cannot be extended."
        : friendlyError(error),
    );
  }
  revalidatePath("/admin/passes");
  return ok(`Extended by ${days} days.`);
}

export async function resendPass(passId: string): Promise<ActionState> {
  const { supabase } = await requireAdmin();
  const { error } = await supabase.functions.invoke("send-pass-email", {
    body: { pass_id: passId },
  });
  if (error)
    return fail(
      "We couldn't send the email. Is the pass still active, with an email address?",
    );
  return ok("Pass emailed to the holder.");
}

// ---------------------------------------------------------------------------
// A7 Users
// ---------------------------------------------------------------------------
const inviteSchema = z.object({
  email: z
    .string()
    .trim()
    .toLowerCase()
    .pipe(z.email({ message: "Enter a valid email address." })),
  full_name: z.string().trim().max(80),
  role: z.enum(["guard", "receptionist", "admin"], {
    message: "Choose a role.",
  }),
});

export async function inviteOperator(
  _: ActionState,
  form: FormData,
): Promise<ActionState> {
  const { supabase } = await requireAdmin();
  const parsed = inviteSchema.safeParse(Object.fromEntries(form));
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const { data, error } = await supabase.functions.invoke("invite-operator", {
    body: parsed.data,
  });
  if (error) {
    const body = await (error as { context?: Response }).context
      ?.json?.()
      .catch(() => null);
    return fail(
      body?.error === "already_exists"
        ? "That email already has an account."
        : "We couldn't add this user.",
    );
  }
  revalidatePath("/admin/users");
  return ok(
    data?.emailed
      ? `Added ${parsed.data.email}. They've been emailed how to sign in.`
      : `Added ${parsed.data.email}.`,
  );
}

export async function setUserRole(
  userId: string,
  role: "guard" | "receptionist" | "admin",
): Promise<ActionState> {
  const { supabase } = await requireAdmin();
  const { error } = await supabase
    .from("profiles")
    .update({ role })
    .eq("id", userId);
  if (error)
    return fail(
      error.message.includes("own role")
        ? "You can't change your own role."
        : friendlyError(error),
    );
  revalidatePath("/admin/users");
  return ok("Role changed.");
}

export async function setUserActive(
  userId: string,
  active: boolean,
): Promise<ActionState> {
  const { supabase } = await requireAdmin();
  const { error } = await supabase
    .from("profiles")
    .update({ is_active: active })
    .eq("id", userId);
  if (error)
    return fail(
      error.message.includes("deactivate themselves")
        ? "You can't deactivate yourself."
        : friendlyError(error),
    );
  revalidatePath("/admin/users");
  return ok(
    active
      ? "User reactivated."
      : "User deactivated. They can no longer use the app.",
  );
}

// ---------------------------------------------------------------------------
// A8 Gates
// ---------------------------------------------------------------------------
export async function addGate(
  _: ActionState,
  form: FormData,
): Promise<ActionState> {
  const { supabase } = await requireAdmin();
  const name = String(form.get("name") ?? "").trim();
  if (name.length < 2) return fail("Give the gate a name.");
  const { error } = await supabase.from("gates").insert({ name });
  if (error)
    return fail(
      error.code === "23505"
        ? "A gate with that name already exists."
        : friendlyError(error),
    );
  revalidatePath("/admin/gates");
  return ok(`${name} added.`);
}

export async function setGateActive(
  gateId: string,
  active: boolean,
): Promise<ActionState> {
  const { supabase } = await requireAdmin();
  const { error } = await supabase
    .from("gates")
    .update({ is_active: active })
    .eq("id", gateId);
  if (error) return fail(friendlyError(error));
  revalidatePath("/admin/gates");
  return ok(
    active
      ? "Gate opened."
      : "Gate closed. Scans there are refused until it is opened again.",
  );
}

// ---------------------------------------------------------------------------
// A10 Flags
// ---------------------------------------------------------------------------
export async function resolveFlag(flagId: string): Promise<ActionState> {
  const { supabase, admin } = await requireAdmin();
  const { error } = await supabase
    .from("flags")
    .update({ resolved_by: admin.id, resolved_at: new Date().toISOString() })
    .eq("id", flagId);
  if (error) return fail(friendlyError(error));
  revalidatePath("/admin", "layout");
  return ok("Resolved.");
}

// ---------------------------------------------------------------------------
// A9 Settings
// ---------------------------------------------------------------------------
const settingsSchema = z.object({
  org_name: z
    .string()
    .trim()
    .min(2, { message: "Enter the organisation name." })
    .max(80),
  allowed_email_domains: z
    .string()
    .transform((s) => [
      ...new Set(
        s
          .split(/[\s,]+/)
          .map((d) => d.trim().toLowerCase().replace(/^@/, ""))
          .filter(Boolean),
      ),
    ])
    .pipe(
      z.array(
        z.string().regex(/^[a-z0-9-]+(\.[a-z0-9-]+)+$/, {
          message: "Domains look like ghii.org (no @).",
        }),
      ),
    ),
  staff_pass_days: z.coerce.number().int().min(1).max(730),
  week_pass_days: z.coerce.number().int().min(1).max(31),
  approval_timeout_minutes: z.coerce.number().int().min(1).max(240),
  auto_close_time: z.string().regex(/^\d{2}:\d{2}$/, { message: "Use HH:MM." }),
  id_photo_retention_days: z.coerce.number().int().min(1).max(365),
  privacy_contact: z
    .string()
    .trim()
    .max(200)
    .transform((v) => v || null),
});

export async function saveSettings(
  _: ActionState,
  form: FormData,
): Promise<ActionState> {
  const { supabase } = await requireAdmin();
  const parsed = settingsSchema.safeParse(Object.fromEntries(form));
  if (!parsed.success) return fail(parsed.error.issues[0].message);
  const { error } = await supabase
    .from("settings")
    .update(parsed.data)
    .eq("id", true);
  if (error) return fail(friendlyError(error));
  revalidatePath("/admin", "layout");
  return ok("Settings saved.");
}
