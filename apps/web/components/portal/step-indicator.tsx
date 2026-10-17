import { Check } from "lucide-react";
import { cn } from "@/lib/utils";

/** "2 of 3" with done (teal check), current (black) and upcoming (grey) steps. */
export function StepIndicator({
  step,
  total,
}: {
  step: number;
  total: number;
}) {
  return (
    <div className="grid justify-items-center gap-3">
      <p className="text-label text-text-muted">
        {step} of {total}
      </p>
      <ol className="flex items-center" aria-label={`Step ${step} of ${total}`}>
        {Array.from({ length: total }, (_, i) => {
          const n = i + 1;
          const state = n < step ? "done" : n === step ? "current" : "upcoming";
          return (
            <li
              key={n}
              className="flex items-center"
              aria-current={state === "current" ? "step" : undefined}
            >
              {i > 0 && (
                <span
                  className={cn(
                    "h-0.5 w-12",
                    n <= step ? "bg-brand" : "bg-border",
                  )}
                  aria-hidden
                />
              )}
              <span
                className={cn(
                  "inline-flex size-9 items-center justify-center rounded-full text-label font-semibold",
                  state === "done" && "bg-brand text-surface",
                  state === "current" && "bg-ink text-surface",
                  state === "upcoming" && "bg-surface-2 text-text-muted",
                )}
              >
                {state === "done" ? (
                  <Check className="size-5" aria-label="Done" />
                ) : (
                  n
                )}
              </span>
            </li>
          );
        })}
      </ol>
    </div>
  );
}
