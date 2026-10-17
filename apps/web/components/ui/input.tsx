import * as React from "react";
import { cn } from "cn";

// Pill input on a white surface, 56 px tall to match buttons.
function Input({ className, type, ...props }: React.ComponentProps<"input">) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        "h-14 w-full min-w-0 rounded-full border border-transparent bg-surface px-5 text-body text-text outline-none placeholder:text-text-muted disabled:pointer-events-none disabled:opacity-50",
        "focus-visible:border-brand focus-visible:ring-[3px] focus-visible:ring-brand/30",
        "aria-invalid:border-danger aria-invalid:ring-danger/20",
        className,
      )}
      {...props}
    />
  );
}

export { Input };
