// send-pass-email — emails a pass with its QR as an inline PNG (docs/SPEC.md → flow 1).
//
//   {}             the signed-in staff member's own pass, read through RLS as them
//   { pass_id }    any pass, to its holder — admins only ("Resend" on the dashboard)
import { createClient } from "@supabase/supabase-js";
import { adminCaller, serviceClient } from "../_shared/admin.ts";
import { json } from "../_shared/http.ts";
import { sendEmail } from "../_shared/mailer.ts";
import { QR_CONTENT_ID, renderPassEmail } from "../_shared/pass-email.ts";
import { qrPngBase64 } from "../_shared/qr.ts";

const COLUMNS =
  "id, type, status, qr_token, status_token, valid_from, valid_until, host_name, contact_email, people!inner(full_name, email, profile_id), vehicles(plate)";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });
  const authorization = req.headers.get("Authorization");
  if (!authorization) return json(401, { error: "not_signed_in" });
  const body = await req.json().catch(() => ({}));

  // deno-lint-ignore no-explicit-any
  let pass: any;
  let to: string | null;
  if (typeof body.pass_id === "string") {
    if (!(await adminCaller(req))) return json(403, { error: "admins_only" });
    const { data, error } = await serviceClient().from("passes").select(COLUMNS).eq("id", body.pass_id).maybeSingle();
    if (error) return json(500, { error: "lookup_failed" });
    pass = data;
    to = pass ? (pass.contact_email ?? pass.people.email) : null;
  } else {
    const asUser = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const { data: userData } = await asUser.auth.getUser();
    const user = userData?.user;
    if (!user?.email) return json(401, { error: "not_signed_in" });
    const { data, error } = await asUser
      .from("passes")
      .select(COLUMNS)
      .eq("type", "staff")
      .eq("people.profile_id", user.id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) return json(500, { error: "lookup_failed" });
    pass = data;
    to = user.email;
  }

  if (!pass) return json(404, { error: "no_pass" });
  if (!to) return json(404, { error: "no_recipient" });
  if (pass.status !== "approved" || new Date(pass.valid_until) <= new Date()) {
    return json(409, { error: "pass_not_active", status: pass.status });
  }

  const portalUrl = (Deno.env.get("PORTAL_URL") ?? "http://localhost:3000").replace(/\/$/, "");
  const visitor = pass.type !== "staff";
  const email = renderPassEmail({
    fullName: pass.people.full_name,
    passType: pass.type,
    plate: pass.vehicles?.plate,
    validFrom: visitor ? pass.valid_from : null,
    validUntil: pass.valid_until,
    hostName: visitor ? pass.host_name : null,
    passUrl: visitor ? `${portalUrl}/r/${pass.status_token}` : `${portalUrl}/pass`,
  });

  try {
    await sendEmail({
      to,
      ...email,
      inline: [
        { filename: "omis-entry-pass.png", contentId: QR_CONTENT_ID, contentType: "image/png", base64: await qrPngBase64(pass.qr_token) },
      ],
    });
  } catch (e) {
    console.error("send-pass-email failed", e);
    return json(502, { error: "email_failed" });
  }
  return json(200, { sent: true });
});
