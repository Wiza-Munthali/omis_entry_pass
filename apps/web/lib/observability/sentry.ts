import { scrubBreadcrumb, scrubEvent } from "./scrub";

const UNUSED_INTEGRATIONS = new Set([
  "BrowserSession",
  "BrowserTracing",
  "SpanStreaming",
  "WebVitals",
]);

/**
 * Sentry settings shared by the browser, Node and edge runtimes. Without
 * NEXT_PUBLIC_SENTRY_DSN nothing is sent (local development, tests).
 * Only errors are reported: no performance traces or session replays, whose span
 * names and recordings could carry personal data.
 */
export function sentryOptions() {
  const dsn = process.env.NEXT_PUBLIC_SENTRY_DSN;
  return {
    dsn,
    enabled: Boolean(dsn),
    environment:
      process.env.NEXT_PUBLIC_SENTRY_ENVIRONMENT ?? process.env.NODE_ENV,
    sendDefaultPii: false,
    tracesSampleRate: 0,
    // Session pings ask Sentry to record the visitor's IP; tracing and web vitals
    // are performance data we don't use.
    integrations: <T extends { name: string }>(defaults: T[]) =>
      defaults.filter((i) => !UNUSED_INTEGRATIONS.has(i.name)),
    beforeSend: scrubEvent,
    beforeBreadcrumb: scrubBreadcrumb,
  };
}
