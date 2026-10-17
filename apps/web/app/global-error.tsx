"use client";

import * as Sentry from "@sentry/nextjs";
import { useEffect } from "react";
import { Button } from "@/components/ui/button";
import "./globals.css";

// Last-resort screen when the root layout itself fails; the error goes to Sentry.
export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    Sentry.captureException(error);
  }, [error]);

  return (
    <html lang="en">
      <body className="bg-bg font-sans text-ink antialiased">
        <main className="mx-auto flex min-h-dvh w-full max-w-md flex-col justify-center gap-4 px-5 text-center">
          <h1 className="text-display font-semibold">Something went wrong</h1>
          <p className="text-body text-text-muted">
            Please try again. If it keeps happening, ask at reception.
          </p>
          <Button onClick={reset} className="self-center">
            Try again
          </Button>
        </main>
      </body>
    </html>
  );
}
