// Error reporting for the Edge Functions (Phase 9). Without SENTRY_DSN nothing is sent and
// failures are only logged, as before.
//
// `serve` replaces Deno.serve: a thrown error becomes a 500 and is reported, and any
// response with status 500+ (a failed lookup, an email that could not be sent) is reported
// with the function name and its error code. `reportError` is for failures a function
// survives (one approver's push failed). Events are scrubbed like the web app's.
import * as Sentry from "@sentry/deno";
import { json } from "./http.ts";
import { scrubBreadcrumb, scrubEvent } from "./scrub.ts";

const dsn = Deno.env.get("SENTRY_DSN");
if (dsn) {
  Sentry.init({
    dsn,
    environment: Deno.env.get("SENTRY_ENVIRONMENT") ?? "development",
    // Supabase's runtime shares globals between requests; the default integrations
    // would mix their breadcrumbs and request data.
    defaultIntegrations: false,
    sendDefaultPii: false,
    tracesSampleRate: 0,
    beforeSend: scrubEvent,
    beforeBreadcrumb: scrubBreadcrumb,
  });
}

// Errors reported so far; lets `serve` skip its generic report when the handler already
// reported the real error. (Concurrent requests in one worker can rarely hide one.)
let reported = 0;

export function reportError(fn: string, error: unknown, context?: string): void {
  reported++;
  console.error(`${fn}${context ? `: ${context}` : ""}`, error);
  if (!dsn) return;
  Sentry.withScope((scope) => {
    scope.setTag("function", fn);
    if (context) scope.setTag("context", context);
    Sentry.captureException(error instanceof Error ? error : new Error(String(error)));
  });
}

export function serve(fn: string, handler: (req: Request) => Promise<Response>): void {
  Deno.serve(async (req) => {
    const before = reported;
    try {
      const res = await handler(req);
      if (res.status >= 500 && dsn && reported === before) {
        const body = await res.clone().json().catch(() => ({}));
        Sentry.withScope((scope) => {
          scope.setTag("function", fn);
          scope.setTag("status", String(res.status));
          Sentry.captureMessage(`${fn} returned ${res.status} ${body?.error ?? ""}`.trim(), "error");
        });
      }
      // Send anything reported during the request before the worker may be stopped.
      if (dsn) await Sentry.flush(2000);
      return res;
    } catch (error) {
      reportError(fn, error);
      if (dsn) await Sentry.flush(2000);
      return json(500, { error: "internal_error" });
    }
  });
}
