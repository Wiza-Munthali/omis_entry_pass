// submit-visitor-request — the only way a visitor request enters the system
// (docs/SPEC.md → Core flows → 2, step 3).
//
// Public endpoint called from the portal in the visitor's browser. Validates with zod,
// then calls submit_visitor_request with the service role; the database does the rate
// limiting (5 per hour per IP and per phone), the person match and the insert.
import { createClient } from "@supabase/supabase-js";
import { z } from "zod";
import { corsHeaders, json } from "../_shared/http.ts";
import { reportError, serve } from "../_shared/report.ts";

const schema = z.object({
  fullName: z.string().trim().min(2).max(80),
  phone: z
    .string()
    .trim()
    .regex(/^\+?[\d\s()-]{8,20}$/),
  email: z.string().trim().toLowerCase().pipe(z.email()),
  idNumber: z.string().trim().min(3).max(30),
  hostName: z.string().trim().min(2).max(80),
  purpose: z.enum(["meeting", "delivery", "contractor", "interview", "other"]),
  passType: z.enum(["day", "week"]),
  startDate: z.iso.date().optional(),
  plate: z
    .string()
    .trim()
    .max(15)
    .regex(/^[A-Za-z0-9\s]*$/)
    .optional(),
  consent: z.literal(true),
});

// Database error keys → form field, so the portal can show them in place.
const FIELD_FOR_ERROR: Record<string, string> = {
  full_name_required: "fullName",
  phone_required: "phone",
  email_required: "email",
  id_number_required: "idNumber",
  host_name_required: "hostName",
  purpose_invalid: "purpose",
  pass_type_must_be_day_or_week: "passType",
  start_date_out_of_range: "startDate",
  invalid_plate: "plate",
};

/** First address in X-Forwarded-For (set by the Supabase gateway). */
function clientIp(req: Request): string | null {
  return req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || null;
}

serve("submit-visitor-request", async (req) => {
  const cors = corsHeaders(req);
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return json(405, { error: "method_not_allowed" }, cors);

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "invalid_json" }, cors);
  }

  const parsed = schema.safeParse(body);
  if (!parsed.success) {
    const fields = [...new Set(parsed.error.issues.map((i) => String(i.path[0])))];
    return json(400, { error: "invalid_input", fields }, cors);
  }
  const input = parsed.data;

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  const { data, error } = await supabase.rpc("submit_visitor_request", {
    p_full_name: input.fullName,
    p_phone: input.phone,
    p_email: input.email,
    p_id_number: input.idNumber,
    p_host_name: input.hostName,
    p_purpose: input.purpose,
    p_pass_type: input.passType,
    p_start_date: input.startDate ?? null,
    p_plate: input.plate || null,
    p_ip: clientIp(req),
  });

  if (error) {
    if (error.message === "rate_limited") return json(429, { error: "rate_limited" }, cors);
    const field = FIELD_FOR_ERROR[error.message];
    if (field) return json(400, { error: "invalid_input", fields: [field] }, cors);
    reportError("submit-visitor-request", error, "submit_visitor_request failed");
    return json(500, { error: "submit_failed" }, cors);
  }

  return json(201, { status_token: data.status_token }, cors);
});
