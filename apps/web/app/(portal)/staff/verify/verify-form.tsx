"use client";

import { useActionState, useEffect, useState, useTransition } from "react";
import { OtpInput } from "@/components/portal/otp-input";
import { SubmitButton } from "@/components/portal/submit-button";
import { resendCode, verifyCode, type FormState } from "../actions";

const RESEND_AFTER_SECONDS = 60;

export function VerifyForm() {
  const [state, action] = useActionState<FormState, FormData>(verifyCode, {});
  const [resendState, setResendState] = useState<FormState>({});
  const [secondsLeft, setSecondsLeft] = useState(RESEND_AFTER_SECONDS);
  const [resending, startResend] = useTransition();

  useEffect(() => {
    if (secondsLeft <= 0) return;
    const timer = setTimeout(() => setSecondsLeft((s) => s - 1), 1000);
    return () => clearTimeout(timer);
  }, [secondsLeft]);

  return (
    <form action={action} className="mt-8 grid gap-6">
      <OtpInput name="code" invalid={Boolean(state.error)} />
      {state.error && (
        <p role="alert" className="text-label text-danger">
          {state.error}
        </p>
      )}
      <SubmitButton pendingText="Checking…">Continue</SubmitButton>

      <p className="text-center text-body text-text-muted" aria-live="polite">
        {resendState.message ?? resendState.error ?? "Didn't get it?"}{" "}
        {secondsLeft > 0 ? (
          <span>Resend in {secondsLeft}s</span>
        ) : (
          <button
            type="button"
            disabled={resending}
            className="font-medium text-brand-strong hover:underline disabled:opacity-50"
            onClick={() =>
              startResend(async () => {
                setResendState(await resendCode());
                setSecondsLeft(RESEND_AFTER_SECONDS);
              })
            }
          >
            {resending ? "Sending…" : "Resend code"}
          </button>
        )}
      </p>
    </form>
  );
}
