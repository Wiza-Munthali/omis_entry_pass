/**
 * Strip personal data and secrets from Sentry events before they leave the app.
 *
 * Visitors and staff give us names, phone numbers, emails, ID numbers and plates, and
 * pass links carry secret tokens (/r/{status_token}, QR tokens). None of that may reach
 * a third-party error tracker, so every event goes through `scrubEvent`:
 * - request cookies, headers, bodies and query strings are dropped;
 * - only the user's id is kept (no email, IP or name);
 * - URLs lose their query string and any token-like path segment;
 * - emails, phone numbers and tokens inside messages are masked;
 * - console breadcrumbs (which may log form values) are dropped.
 */

/** Base64url secrets are 32+ characters (24 or 32 random bytes); JWT parts are longer. */
const TOKEN = /[A-Za-z0-9_-]{32,}/g;
const EMAIL = /[^\s@"'<>()]+@[^\s@"'<>()]+\.[A-Za-z]{2,}/g;
/** Digit runs split by spaces or dashes; 9+ digits is a phone number (dates have 8). */
const PHONE = /\+?\d[\d\s-]{6,}\d/g;
const maskPhone = (run: string) =>
  run.replace(/\D/g, "").length >= 9 ? "[phone]" : run;

export function scrubText(text: string): string {
  return text
    .replace(EMAIL, "[email]")
    .replace(TOKEN, "[token]")
    .replace(PHONE, maskPhone);
}

export function scrubUrl(url: string): string {
  const [withoutQuery] = url.split(/[?#]/);
  return withoutQuery.replace(TOKEN, "[token]").replace(EMAIL, "[email]");
}

type Breadcrumb = {
  category?: string;
  message?: string;
  data?: Record<string, unknown>;
};

type Exception = { value?: string };

/** The parts of a Sentry event we touch; everything else passes through unchanged. */
export type ScrubbableEvent = {
  message?: string;
  request?: {
    url?: string;
    cookies?: unknown;
    headers?: unknown;
    data?: unknown;
    query_string?: unknown;
    env?: unknown;
  };
  user?: { id?: string | number; [key: string]: unknown };
  breadcrumbs?: Breadcrumb[];
  exception?: { values?: Exception[] };
  transaction?: string;
};

export function scrubBreadcrumb<B extends Breadcrumb>(crumb: B): B | null {
  if (crumb.category === "console") return null;
  const data = crumb.data ? { ...crumb.data } : undefined;
  if (data) {
    for (const key of ["url", "from", "to"]) {
      if (typeof data[key] === "string") data[key] = scrubUrl(data[key]);
    }
    delete data.body;
  }
  return {
    ...crumb,
    ...(crumb.message !== undefined && { message: scrubText(crumb.message) }),
    ...(data && { data }),
  };
}

export function scrubEvent<E extends ScrubbableEvent>(event: E): E {
  const out: E = { ...event };
  if (out.message) out.message = scrubText(out.message);
  if (out.transaction) out.transaction = scrubUrl(out.transaction);
  if (out.request) {
    out.request = out.request.url ? { url: scrubUrl(out.request.url) } : {};
  }
  if (out.user) {
    out.user = out.user.id !== undefined ? { id: out.user.id } : {};
  }
  if (out.breadcrumbs) {
    out.breadcrumbs = out.breadcrumbs
      .map(scrubBreadcrumb)
      .filter((c): c is Breadcrumb => c !== null);
  }
  if (out.exception?.values) {
    out.exception = {
      ...out.exception,
      values: out.exception.values.map((v) =>
        v.value ? { ...v, value: scrubText(v.value) } : v,
      ),
    };
  }
  return out;
}
