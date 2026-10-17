"use client";

import { useActionState } from "react";
import { Field } from "@/components/portal/field";
import { SubmitButton } from "@/components/portal/submit-button";
import { sendCode, type FormState } from "./actions";

export function EmailForm({ domains }: { domains: string[] }) {
  const [state, action] = useActionState<FormState, FormData>(sendCode, {});
  const hint = domains.length
    ? `Use your ${domains.map((d) => `@${d}`).join(" or ")} address.`
    : undefined;

  return (
    <form action={action} className="mt-8 grid gap-6" noValidate>
      <Field
        label="Work email"
        name="email"
        type="email"
        inputMode="email"
        autoComplete="email"
        autoCapitalize="none"
        spellCheck={false}
        placeholder={domains[0] ? `name@${domains[0]}` : "name@organisation"}
        defaultValue={String(state.values?.email ?? "")}
        hint={hint}
        error={state.fields?.email}
        required
      />
      <SubmitButton pendingText="Sending…">Send code</SubmitButton>
    </form>
  );
}
