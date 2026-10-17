// notify-approvers — tells the people who can decide a visitor request about it
// (docs/SPEC.md → Notifications):
//   kind "new"        → active receptionists (admins if there are none), email + push
//   kind "escalated"  → all active admins, email + push
//
// Called only by the database (new-request trigger and the escalation job, via pg_net)
// with the shared secret in x-internal-secret. Push is skipped until FCM is configured.
import { createClient } from "@supabase/supabase-js";
import { pushConfigured, sendPush } from "../_shared/fcm.ts";
import { json, safeEqual } from "../_shared/http.ts";
import { sendEmail } from "../_shared/mailer.ts";
import { renderApprovalRequestEmail } from "../_shared/pass-email.ts";
import { reportError, serve } from "../_shared/report.ts";

type Recipient = { id: string; email: string; fcm_token: string | null };

serve("notify-approvers", async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  const expected = Deno.env.get("INTERNAL_HOOK_SECRET");
  if (!expected || !safeEqual(req.headers.get("x-internal-secret") ?? "", expected)) {
    return json(401, { error: "unauthorized" });
  }

  const { pass_id: passId, kind } = await req.json().catch(() => ({}));
  if (typeof passId !== "string" || (kind !== "new" && kind !== "escalated")) {
    return json(400, { error: "pass_id_and_kind_required" });
  }

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  const { data: pass, error } = await supabase
    .from("passes")
    .select("id, type, status, source, host_name, valid_from, valid_until, created_at, people(full_name), requester:profiles!passes_requested_by_fkey(full_name)")
    .eq("id", passId)
    .maybeSingle();
  if (error) return json(500, { error: "lookup_failed", detail: error.message });
  if (!pass) return json(404, { error: "no_pass" });
  if (pass.status !== "pending") return json(200, { skipped: "already_decided" });

  const recipientsFor = async (role: "receptionist" | "admin") =>
    ((await supabase.from("profiles").select("id, email, fcm_token").eq("role", role).eq("is_active", true)).data ??
      []) as Recipient[];

  let recipients = kind === "escalated" ? await recipientsFor("admin") : await recipientsFor("receptionist");
  if (kind === "new" && recipients.length === 0) recipients = await recipientsFor("admin");

  const fullName = (pass.people as unknown as { full_name: string }).full_name;
  const requester = (pass.requester as unknown as { full_name: string | null } | null)?.full_name;
  const waited = Math.max(1, Math.round((Date.now() - new Date(pass.created_at).getTime()) / 60_000));

  const email = renderApprovalRequestEmail({
    fullName,
    passType: pass.type,
    hostName: pass.host_name,
    source: pass.source,
    requestedBy: requester,
    requestedAt: pass.created_at,
    validFrom: pass.valid_from,
    validUntil: pass.valid_until,
    escalatedMinutes: kind === "escalated" ? waited : null,
  });

  const emailResults = await Promise.allSettled(recipients.map((r) => sendEmail({ to: r.email, ...email })));
  emailResults
    .filter((r): r is PromiseRejectedResult => r.status === "rejected")
    .forEach((r) => reportError("notify-approvers", r.reason, "email failed"));

  let push = { sent: 0, invalid: [] as string[] };
  if (pushConfigured()) {
    try {
      push = await sendPush(recipients.map((r) => r.fcm_token).filter((t): t is string => !!t), {
        title: kind === "escalated" ? `Waiting ${waited} min: ${fullName}` : `New visitor: ${fullName}`,
        body: `${pass.host_name ?? "Visitor"} · ${pass.type === "day" ? "one day" : "one week"}${pass.source === "gate" ? " · at the gate" : ""}`,
        data: { pass_id: pass.id, kind },
      });
      if (push.invalid.length) await supabase.from("profiles").update({ fcm_token: null }).in("fcm_token", push.invalid);
    } catch (e) {
      reportError("notify-approvers", e, "push failed");
    }
  }

  return json(200, {
    recipients: recipients.length,
    emailed: emailResults.filter((r) => r.status === "fulfilled").length,
    pushed: push.sent,
    push_configured: pushConfigured(),
  });
});
