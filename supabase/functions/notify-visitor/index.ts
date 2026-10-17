// notify-visitor — emails a web visitor the decision on their request: the pass with
// its QR when approved, the reason when rejected (docs/SPEC.md → Notifications).
//
// Called only by the database (passes_notify_visitor trigger via pg_net) with the
// shared secret from Vault in x-internal-secret. Reads with the service role.
import { createClient } from "@supabase/supabase-js";
import { json, safeEqual } from "../_shared/http.ts";
import { sendEmail } from "../_shared/mailer.ts";
import { QR_CONTENT_ID, renderPassEmail, renderRejectionEmail } from "../_shared/pass-email.ts";
import { qrPngBase64 } from "../_shared/qr.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

  const expected = Deno.env.get("INTERNAL_HOOK_SECRET");
  const given = req.headers.get("x-internal-secret") ?? "";
  if (!expected || !safeEqual(given, expected)) return json(401, { error: "unauthorized" });

  const { pass_id: passId } = await req.json().catch(() => ({}));
  if (typeof passId !== "string") return json(400, { error: "pass_id_required" });

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });
  const { data: pass, error } = await supabase
    .from("passes")
    .select(
      "id, type, status, qr_token, status_token, valid_from, valid_until, host_name, reject_reason, contact_email, people(full_name), vehicles(plate)",
    )
    .eq("id", passId)
    .maybeSingle();

  if (error) return json(500, { error: "lookup_failed" });
  if (!pass || !pass.contact_email) return json(404, { error: "no_recipient" });

  const fullName = (pass.people as unknown as { full_name: string }).full_name;
  const plate = (pass.vehicles as unknown as { plate: string } | null)?.plate;
  const statusUrl = `${(Deno.env.get("PORTAL_URL") ?? "http://localhost:3000").replace(/\/$/, "")}/r/${pass.status_token}`;

  try {
    if (pass.status === "approved") {
      const email = renderPassEmail({
        fullName,
        passType: pass.type,
        plate,
        validFrom: pass.valid_from,
        validUntil: pass.valid_until,
        hostName: pass.host_name,
        passUrl: statusUrl,
      });
      await sendEmail({
        to: pass.contact_email,
        ...email,
        inline: [
          {
            filename: "omis-entry-pass.png",
            contentId: QR_CONTENT_ID,
            contentType: "image/png",
            base64: await qrPngBase64(pass.qr_token),
          },
        ],
      });
    } else if (pass.status === "rejected") {
      await sendEmail({
        to: pass.contact_email,
        ...renderRejectionEmail({
          fullName,
          reason: pass.reject_reason ?? "No reason given",
          hostName: pass.host_name,
          statusUrl,
        }),
      });
    } else {
      return json(409, { error: "not_decided", status: pass.status });
    }
  } catch (e) {
    console.error("notify-visitor failed", e);
    return json(502, { error: "email_failed" });
  }

  return json(200, { sent: true });
});
