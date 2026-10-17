import Link from "next/link";
import { ArrowLeft } from "lucide-react";

const BACK_CLASS =
  "absolute left-0 inline-flex size-12 items-center justify-center rounded-full bg-surface text-ink hover:bg-surface-2";

/** Circular back button (a link, or a callback for in-page steps) with a centred title. */
export function ScreenHeader({
  title,
  backHref,
  onBack,
}: {
  title?: string;
  backHref?: string;
  onBack?: () => void;
}) {
  return (
    <header className="relative flex min-h-12 items-center justify-center">
      {onBack ? (
        <button
          type="button"
          onClick={onBack}
          aria-label="Back"
          className={BACK_CLASS}
        >
          <ArrowLeft className="size-5" />
        </button>
      ) : (
        backHref && (
          <Link href={backHref} aria-label="Back" className={BACK_CLASS}>
            <ArrowLeft className="size-5" />
          </Link>
        )
      )}
      {title && (
        <h1 className="px-14 text-center text-title font-semibold text-ink">
          {title}
        </h1>
      )}
    </header>
  );
}
