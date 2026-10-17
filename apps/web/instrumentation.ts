import * as Sentry from "@sentry/nextjs";
import { sentryOptions } from "@/lib/observability/sentry";

export function register() {
  Sentry.init(sentryOptions());
}

// Errors thrown while rendering pages, route handlers and server actions.
export const onRequestError = Sentry.captureRequestError;
