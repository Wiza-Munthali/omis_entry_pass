import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "cn";
import { Slot } from "radix-ui";

// Spec components: primary = full-width black pill, 56 px, teal label;
// secondary = white pill with ink text (destructive variant uses danger text).
const buttonVariants = cva(
  "inline-flex shrink-0 items-center justify-center gap-2 rounded-full font-semibold whitespace-nowrap transition-colors outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-5",
  {
    variants: {
      variant: {
        primary: "bg-ink text-brand hover:bg-ink-2",
        secondary: "bg-surface text-ink hover:bg-surface-2",
        destructive: "bg-surface text-danger hover:bg-danger-soft",
        icon: "bg-surface-2 text-ink hover:bg-border",
        link: "h-auto px-0 font-medium text-brand-strong underline-offset-4 hover:underline",
      },
      size: {
        default: "h-14 w-full px-6 text-body",
        sm: "h-11 px-5 text-label",
        icon: "size-12",
        inline: "",
      },
    },
    defaultVariants: {
      variant: "primary",
      size: "default",
    },
  },
);

function Button({
  className,
  variant = "primary",
  size = "default",
  asChild = false,
  ...props
}: React.ComponentProps<"button"> &
  VariantProps<typeof buttonVariants> & {
    asChild?: boolean;
  }) {
  const Comp = asChild ? Slot.Root : "button";

  return (
    <Comp
      data-slot="button"
      data-variant={variant}
      data-size={size}
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  );
}

export { Button, buttonVariants };
