import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "cn";

// Status and tag chips (pill). Status tones use the spec's foreground-on-soft pairs.
const chipVariants = cva(
  "inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-label font-medium [&_svg]:size-4",
  {
    variants: {
      tone: {
        neutral: "bg-surface-2 text-ink",
        success: "bg-success-soft text-success",
        warning: "bg-warning-soft text-warning",
        danger: "bg-danger-soft text-danger",
        info: "bg-info-soft text-info",
      },
    },
    defaultVariants: { tone: "neutral" },
  },
);

function Chip({
  className,
  tone,
  ...props
}: React.ComponentProps<"span"> & VariantProps<typeof chipVariants>) {
  return (
    <span
      data-slot="chip"
      className={cn(chipVariants({ tone, className }))}
      {...props}
    />
  );
}

export { Chip };
