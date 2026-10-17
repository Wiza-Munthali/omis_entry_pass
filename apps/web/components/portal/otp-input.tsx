"use client";

import { useRef, useState } from "react";
import { cn } from "cn";

const LENGTH = 6;

/**
 * Six rounded digit boxes. Supports typing, backspace, paste and the browser's
 * one-time-code autofill; submits the form when all six digits are in.
 */
export function OtpInput({
  name,
  invalid,
}: {
  name: string;
  invalid?: boolean;
}) {
  const [digits, setDigits] = useState<string[]>(Array(LENGTH).fill(""));
  const refs = useRef<(HTMLInputElement | null)[]>([]);

  function fill(start: number, text: string) {
    const incoming = text
      .replace(/\D/g, "")
      .slice(0, LENGTH - start)
      .split("");
    if (!incoming.length) return;
    const next = [...digits];
    incoming.forEach((d, i) => (next[start + i] = d));
    setDigits(next);
    const last = Math.min(start + incoming.length, LENGTH - 1);
    refs.current[last]?.focus();
    if (next.every(Boolean)) {
      // Let React commit the hidden input value before submitting.
      requestAnimationFrame(() => refs.current[0]?.form?.requestSubmit());
    }
  }

  return (
    <div
      className="flex justify-between gap-2"
      role="group"
      aria-label="6-digit code"
    >
      <input type="hidden" name={name} value={digits.join("")} />
      {digits.map((digit, i) => (
        <input
          key={i}
          ref={(el) => {
            refs.current[i] = el;
          }}
          value={digit}
          inputMode="numeric"
          autoComplete={i === 0 ? "one-time-code" : "off"}
          aria-label={`Digit ${i + 1}`}
          aria-invalid={invalid || undefined}
          autoFocus={i === 0}
          className={cn(
            "h-16 w-full min-w-0 rounded-2xl border-2 border-transparent bg-surface text-center text-display font-semibold text-ink outline-none",
            "focus:border-brand",
            invalid && "border-danger",
          )}
          onChange={(e) => {
            const value = e.target.value;
            if (value.length > 1) return fill(i, value);
            const next = [...digits];
            next[i] = value.replace(/\D/g, "");
            setDigits(next);
            if (next[i] && i < LENGTH - 1) refs.current[i + 1]?.focus();
            if (next.every(Boolean))
              requestAnimationFrame(() =>
                refs.current[0]?.form?.requestSubmit(),
              );
          }}
          onKeyDown={(e) => {
            if (e.key === "Backspace" && !digits[i] && i > 0)
              refs.current[i - 1]?.focus();
          }}
          onPaste={(e) => {
            e.preventDefault();
            fill(i, e.clipboardData.getData("text"));
          }}
        />
      ))}
    </div>
  );
}
