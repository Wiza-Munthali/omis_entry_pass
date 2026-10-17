// invite-operator — an admin adds a guard, receptionist or admin (docs/SPEC.md → Roles:
// "Operator accounts are created only by admins (invite by email)").
//
// Creates the account with the role in app_metadata (only settable server-side; the
// sign-up hook lets role'd accounts use any email domain), then emails them how to
// sign in. Caller must be an active admin.
import { adminCaller, serviceClient } from "../_shared/admin.ts";
import { json } from "../_shared/http.ts";
import { sendEmail } from "../_shared/mailer.ts";
import { renderOperatorInviteEmail } from "../_shared/pass-email.ts";
import { reportError, serve } from "../_shared/report.ts";

const ROLES = ["guard", "receptionist", "admin"] as const;
type Role = (typeof ROLES)[number];

serve("invite-operator", async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  if (!(await adminCaller(req))) return json(403, { error: "admins_only" });

  const body = await req.json().catch(() => ({}));
  const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
  const role = body.role as Role;
  const fullName = typeof body.full_name === "string" ? body.full_name.trim() : "";
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return json(400, { error: "invalid_email" });
  if (!ROLES.includes(role)) return json(400, { error: "invalid_role" });

  const supabase = serviceClient();
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    email_confirm: true,
    app_metadata: { role },
    user_metadata: fullName ? { full_name: fullName } : {},
  });
  if (error) {
    const exists = /already|registered|exists/i.test(error.message);
    return json(exists ? 409 : 500, { error: exists ? "already_exists" : "create_failed", detail: error.message });
  }

  const { data: settings } = await supabase.from("settings").select("org_name").single();
  try {
    await sendEmail({ to: email, ...renderOperatorInviteEmail({ fullName, role, orgName: settings?.org_name ?? "GHII" }) });
  } catch (e) {
    reportError("invite-operator", e, "email failed");
    return json(200, { user_id: data.user?.id, emailed: false });
  }
  return json(200, { user_id: data.user?.id, emailed: true });
});
