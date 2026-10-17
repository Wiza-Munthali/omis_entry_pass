// send-pass-email — emails the signed-in staff member their pass: QR as an inline PNG,
// a link to /pass, and a plain-text fallback (docs/SPEC.md → Core flows → 1, step 5–6).
//
// Called by the web portal with the user's session (Authorization: Bearer <access token>).
// The pass is read through RLS as that user, so nobody can email themselves another
// person's pass. Visitor pass emails (Phase 4) will add a service-role path.
import { createClient } from "@supabase/supabase-js";
import QRCode from "qrcode";
import { sendEmail } from "../_shared/mailer.ts";
import { QR_CONTENT_ID, renderPassEmail } from "../_shared/pass-email.ts";
import { colors } from "../_shared/tokens.ts";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const authorization = req.headers.get("Authorization");
  if (!authorization) return json(401, { error: "not_signed_in" });

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser();
  const user = userData?.user;
  if (userError || !user?.email) return json(401, { error: "not_signed_in" });

  const { data: pass, error } = await supabase
    .from("passes")
    .select("id, type, status, qr_token, valid_until, people!inner(full_name, profile_id), vehicles(plate)")
    .eq("type", "staff")
    .eq("people.profile_id", user.id)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) return json(500, { error: "lookup_failed" });
  if (!pass) return json(404, { error: "no_pass" });
  if (pass.status !== "approved" || new Date(pass.valid_until) <= new Date()) {
    return json(409, { error: "pass_not_active", status: pass.status });
  }

  const person = pass.people as unknown as { full_name: string };
  const vehicle = pass.vehicles as unknown as { plate: string } | null;
  const portalUrl = Deno.env.get("PORTAL_URL") ?? "http://localhost:3000";

  const qrDataUrl = await QRCode.toDataURL(pass.qr_token, {
    errorCorrectionLevel: "M",
    margin: 2,
    width: 560,
    color: { dark: colors.ink, light: colors.surface },
  });

  const email = renderPassEmail({
    fullName: person.full_name,
    passType: pass.type,
    plate: vehicle?.plate,
    validUntil: pass.valid_until,
    passUrl: `${portalUrl}/pass`,
  });

  try {
    await sendEmail({
      to: user.email,
      ...email,
      inline: [
        {
          filename: "omis-entry-pass.png",
          contentId: QR_CONTENT_ID,
          contentType: "image/png",
          base64: qrDataUrl.slice(qrDataUrl.indexOf(",") + 1),
        },
      ],
    });
  } catch (e) {
    console.error("send-pass-email failed", e);
    return json(502, { error: "email_failed" });
  }

  return json(200, { sent: true });
});
