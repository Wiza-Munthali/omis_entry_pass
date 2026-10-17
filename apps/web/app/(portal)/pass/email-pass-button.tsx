"use client";

import { useActionState } from "react";
import { Mail } from "lucide-react";
import { SubmitButton } from "@/components/portal/submit-button";
import { emailPass, type FormState } from "../staff/actions";

export function EmailPassButton() {
  const [state, action] = useActionState<FormState, FormData>(emailPass, {});
  return (
    <form action={action} className="grid gap-2">
      <SubmitButton pendingText="Sending…">
        <Mail aria-hidden />
        <span className="h-6 w-px bg-brand/40" aria-hidden />
        Email me my pass
      </SubmitButton>
      <p
        aria-live="polite"
        className={
          state.error
            ? "text-center text-label text-danger"
            : "text-center text-label text-success"
        }
      >
        {state.error ?? state.message}
      </p>
    </form>
  );
}
