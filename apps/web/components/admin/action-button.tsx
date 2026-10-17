"use client";

import { useRef, useState, useTransition } from "react";
import { LoaderCircle } from "lucide-react";
import { cn } from "@/lib/utils";
import type { ActionState } from "@/app/admin/actions";

type Field = {
  name: string;
  label: string;
  required?: boolean;
  placeholder?: string;
  options?: { value: string; label: string }[];
};

const STYLES = {
  primary: "bg-brand text-ink hover:bg-brand-strong hover:text-surface",
  dark: "bg-ink text-brand hover:bg-ink-2",
  outline: "border border-border bg-surface text-ink hover:bg-surface-2",
  danger: "border border-border bg-surface text-danger hover:bg-danger-soft",
} as const;

/**
 * A button that runs a server action, optionally after a confirmation dialog that can
 * ask for one value (a reason, a number of days, a role). Shows the result next to it.
 */
export function ActionButton({
  label,
  run,
  variant = "outline",
  confirm,
  field,
  size = "sm",
}: {
  label: string;
  run: (value?: string) => Promise<ActionState>;
  variant?: keyof typeof STYLES;
  confirm?: { title: string; body?: string; action: string };
  field?: Field;
  size?: "sm" | "md";
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const [pending, start] = useTransition();
  const [result, setResult] = useState<ActionState>({});

  const go = (value?: string) =>
    start(async () => {
      setResult(await run(value));
    });

  return (
    <span className="inline-flex flex-col items-start gap-1">
      <button
        type="button"
        disabled={pending}
        onClick={() => (confirm ? dialog.current?.showModal() : go())}
        className={cn(
          "inline-flex items-center gap-2 rounded-full font-medium whitespace-nowrap transition-colors disabled:opacity-50",
          size === "sm" ? "h-9 px-4 text-label" : "h-11 px-5 text-body",
          STYLES[variant],
        )}
      >
        {pending && (
          <LoaderCircle className="size-4 animate-spin" aria-hidden />
        )}
        {label}
      </button>
      {(result.error || result.message) && (
        <span
          role="status"
          className={cn(
            "max-w-64 text-caption",
            result.error ? "text-danger" : "text-success",
          )}
        >
          {result.error ?? result.message}
        </span>
      )}
      {confirm && (
        <dialog
          ref={dialog}
          className="m-auto w-[min(92vw,440px)] rounded-card bg-surface p-6 text-text backdrop:bg-ink/40"
        >
          <form
            method="dialog"
            onSubmit={(e) => {
              const value = field
                ? String(new FormData(e.currentTarget).get(field.name) ?? "")
                : undefined;
              if (field?.required && !value?.trim()) {
                e.preventDefault();
                return;
              }
              go(value);
            }}
            className="grid gap-4"
          >
            <h2 className="text-title font-semibold text-ink">
              {confirm.title}
            </h2>
            {confirm.body && (
              <p className="text-body text-text-muted">{confirm.body}</p>
            )}
            {field && (
              <label className="grid gap-1.5 text-label font-medium">
                {field.label}
                {field.options ? (
                  <select
                    name={field.name}
                    className="h-11 rounded-full border border-border bg-surface px-4"
                    defaultValue={field.options[0]?.value}
                  >
                    {field.options.map((o) => (
                      <option key={o.value} value={o.value}>
                        {o.label}
                      </option>
                    ))}
                  </select>
                ) : (
                  <input
                    name={field.name}
                    required={field.required}
                    placeholder={field.placeholder}
                    className="h-11 rounded-full border border-border bg-surface px-4 font-normal"
                  />
                )}
              </label>
            )}
            <div className="flex justify-end gap-2">
              <button
                type="button"
                onClick={() => dialog.current?.close()}
                className="h-10 rounded-full border border-border px-4 font-medium hover:bg-surface-2"
              >
                Cancel
              </button>
              <button
                type="submit"
                className={cn(
                  "h-10 rounded-full px-4 font-medium",
                  STYLES[variant === "danger" ? "danger" : "dark"],
                )}
              >
                {confirm.action}
              </button>
            </div>
          </form>
        </dialog>
      )}
    </span>
  );
}
