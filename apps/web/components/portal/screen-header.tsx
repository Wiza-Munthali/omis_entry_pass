import Link from "next/link";
import { ArrowLeft } from "lucide-react";

/** Circular back button with a centred screen title. */
export function ScreenHeader({
  title,
  backHref,
}: {
  title?: string;
  backHref?: string;
}) {
  return (
    <header className="relative flex min-h-12 items-center justify-center">
      {backHref && (
        <Link
          href={backHref}
          aria-label="Back"
          className="absolute left-0 inline-flex size-12 items-center justify-center rounded-full bg-surface text-ink hover:bg-surface-2"
        >
          <ArrowLeft className="size-5" />
        </Link>
      )}
      {title && <h1 className="text-title font-semibold text-ink">{title}</h1>}
    </header>
  );
}
