"use client";

import { useActionState, useState } from "react";
import { LoaderCircle } from "lucide-react";
import { adminSendCode, adminVerifyCode, type ActionState } from "../actions";

export function SignInForm() {
  const [sent, setSent] = useState(false);
  const [sendState, send, sending] = useActionState(
    async (s: ActionState, f: FormData) => {
      const r = await adminSendCode(s, f);
      if (r.message === "sent") setSent(true);
      return r;
    },
    {},
  );
  const [verifyState, verify, verifying] = useActionState(adminVerifyCode, {});

  const input =
    "h-12 w-full rounded-full border border-border bg-surface px-5 text-body outline-none focus-visible:border-brand focus-visible:ring-[3px] focus-visible:ring-brand/30";
  const button =
    "inline-flex h-12 w-full items-center justify-center gap-2 rounded-full bg-ink font-semibold text-brand hover:bg-ink-2 disabled:opacity-50";

  return sent ? (
    <form action={verify} className="mt-8 grid gap-4">
      <label className="grid gap-2 text-label font-medium">
        6-digit code
        <input
          name="code"
          inputMode="numeric"
          autoComplete="one-time-code"
          maxLength={6}
          className={`${input} tracking-[0.5em]`}
          autoFocus
        />
      </label>
      {verifyState.error && (
        <p role="alert" className="text-label text-danger">
          {verifyState.error}
        </p>
      )}
      <button className={button} disabled={verifying}>
        {verifying && <LoaderCircle className="size-5 animate-spin" />} Sign in
      </button>
      <button
        type="button"
        onClick={() => setSent(false)}
        className="text-label font-medium text-brand-strong hover:underline"
      >
        Use a different email
      </button>
    </form>
  ) : (
    <form action={send} className="mt-8 grid gap-4">
      <label className="grid gap-2 text-label font-medium">
        Email
        <input
          name="email"
          type="email"
          autoComplete="email"
          className={input}
          placeholder="name@organisation"
          autoFocus
        />
      </label>
      {sendState.error && (
        <p role="alert" className="text-label text-danger">
          {sendState.error}
        </p>
      )}
      <button className={button} disabled={sending}>
        {sending && <LoaderCircle className="size-5 animate-spin" />} Send code
      </button>
    </form>
  );
}
