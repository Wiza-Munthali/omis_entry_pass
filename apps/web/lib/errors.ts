// Plain-language messages for the error keys raised by the database RPCs and auth.
const MESSAGES: Record<string, string> = {
  email_domain_not_allowed: "Use your work email address to get a staff pass.",
  id_number_in_use:
    "That ID number is already on another record. Please ask reception to help you.",
  pass_revoked: "Your staff pass has been revoked. Please contact reception.",
  full_name_required: "Enter your full name.",
  id_number_required: "Enter your ID number.",
  invalid_plate: "Use letters and numbers only for the plate, e.g. BT 4521.",
  otp_expired:
    "That code is wrong or has expired. Check the latest email or send a new code.",
  over_email_send_rate_limit:
    "Too many codes requested. Wait a minute and try again.",
};

export const GENERIC_ERROR = "Something went wrong. Please try again.";

/** Maps an RPC/auth error message or code to text for the user. */
export function friendlyError(
  error: { message?: string; code?: string } | null | undefined,
): string {
  if (!error) return GENERIC_ERROR;
  for (const key of [error.code, error.message]) {
    if (key && MESSAGES[key]) return MESSAGES[key];
  }
  if (error.message && /work email/i.test(error.message))
    return MESSAGES.email_domain_not_allowed;
  return GENERIC_ERROR;
}
