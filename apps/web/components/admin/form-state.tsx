"use client";

import { useActionState } from "react";
import { LoaderCircle } from "lucide-react";
import { cn } from "@/lib/utils";
import type { ActionState } from "@/app/admin/actions";

/** A form bound to a server action, with a submit button and the result message. */
export function ActionForm({
  action,
  submit,
  children,
  className,
}: {
  action: (state: ActionState, form: FormData) => Promise<ActionState>;
  submit: string;
  children: React.ReactNode;
  className?: string;
}) {
  const [state, run, pending] = useActionState(action, {});
  return (
    <form action={run} className={cn("grid gap-4", className)}>
      {children}
      <div className="flex flex-wrap items-center gap-3">
        <button
          type="submit"
          disabled={pending}
          className="inline-flex h-11 items-center gap-2 rounded-full bg-ink px-5 font-medium text-brand hover:bg-ink-2 disabled:opacity-50"
        >
          {pending && (
            <LoaderCircle className="size-4 animate-spin" aria-hidden />
          )}
          {submit}
        </button>
        {(state.error || state.message) && (
          <span
            role="status"
            className={
              state.error ? "text-label text-danger" : "text-label text-success"
            }
          >
            {state.error ?? state.message}
          </span>
        )}
      </div>
    </form>
  );
}

export function TextField({
  label,
  name,
  defaultValue,
  type = "text",
  hint,
  ...props
}: React.ComponentProps<"input"> & {
  label: string;
  name: string;
  hint?: string;
}) {
  return (
    <label className="grid gap-1.5 text-label font-medium text-text">
      {label}
      <input
        name={name}
        type={type}
        defaultValue={defaultValue}
        className="h-11 rounded-full border border-border bg-surface px-4 font-normal outline-none focus-visible:border-brand focus-visible:ring-[3px] focus-visible:ring-brand/30"
        {...props}
      />
      {hint && <span className="font-normal text-text-muted">{hint}</span>}
    </label>
  );
}
