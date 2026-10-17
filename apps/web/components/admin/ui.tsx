import Link from "next/link";
import { ChevronRight, Home } from "lucide-react";
import { cn } from "@/lib/utils";

/** Breadcrumb, title, one-line subtitle and actions on the right (spec: web dashboard). */
export function PageHeader({
  title,
  subtitle,
  actions,
}: {
  title: string;
  subtitle: string;
  actions?: React.ReactNode;
}) {
  return (
    <header className="flex flex-wrap items-end justify-between gap-4">
      <div>
        <nav
          aria-label="Breadcrumb"
          className="flex items-center gap-2 text-label text-text-muted"
        >
          <Link href="/admin" aria-label="Overview" className="hover:text-ink">
            <Home className="size-4" />
          </Link>
          <ChevronRight className="size-4" aria-hidden />
          <span className="font-medium text-brand-strong">{title}</span>
        </nav>
        <h1 className="mt-2 text-display font-semibold text-ink">{title}</h1>
        <p className="text-body text-text-muted">{subtitle}</p>
      </div>
      {actions && (
        <div className="flex flex-wrap items-center gap-2">{actions}</div>
      )}
    </header>
  );
}

export function Panel({
  title,
  subtitle,
  actions,
  children,
  className,
}: {
  title?: string;
  subtitle?: string;
  actions?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <section
      className={cn(
        "rounded-card border border-border bg-surface p-5",
        className,
      )}
    >
      {(title || actions) && (
        <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
          <div>
            {title && (
              <h2 className="text-title font-semibold text-ink">{title}</h2>
            )}
            {subtitle && (
              <p className="text-label text-text-muted">{subtitle}</p>
            )}
          </div>
          {actions}
        </div>
      )}
      {children}
    </section>
  );
}

const PILL = {
  success: "bg-success-soft text-success",
  warning: "bg-warning-soft text-warning",
  danger: "bg-danger-soft text-danger",
  info: "bg-info-soft text-info",
  neutral: "bg-surface-2 text-text-muted",
  brand: "bg-brand-soft text-brand-strong",
} as const;

/** Soft-coloured status pill with a dot (spec: tables). */
export function Pill({
  tone,
  children,
  dot = true,
}: {
  tone: keyof typeof PILL;
  children: React.ReactNode;
  dot?: boolean;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-label font-medium whitespace-nowrap",
        PILL[tone],
      )}
    >
      {dot && <span className="size-1.5 rounded-full bg-current" aria-hidden />}
      {children}
    </span>
  );
}

export function TypePill({ type }: { type: string }) {
  return type === "staff" ? (
    <Pill tone="brand" dot={false}>
      Staff
    </Pill>
  ) : (
    <Pill tone="info" dot={false}>
      {type === "week" ? "Visitor · week" : "Visitor · day"}
    </Pill>
  );
}

export function Initials({ name }: { name: string }) {
  const parts = name.trim().split(/\s+/);
  const text = (
    (parts[0]?.[0] ?? "") + (parts.length > 1 ? parts[parts.length - 1][0] : "")
  ).toUpperCase();
  return (
    <span className="inline-flex size-8 shrink-0 items-center justify-center rounded-full bg-surface-2 text-caption font-semibold text-ink">
      {text}
    </span>
  );
}

/** Table shell: rounded header row, hairline dividers, scrolls sideways on narrow screens. */
export function Table({
  head,
  children,
  caption,
}: {
  head: string[];
  children: React.ReactNode;
  caption?: string;
}) {
  return (
    <div className="-mx-1 overflow-x-auto">
      <table className="w-full min-w-[720px] border-separate border-spacing-0 text-left text-label">
        {caption && <caption className="sr-only">{caption}</caption>}
        <thead>
          <tr>
            {head.map((h, i) => (
              <th
                key={h || i}
                scope="col"
                className={cn(
                  "bg-surface-2 px-3 py-2.5 font-medium text-text-muted",
                  i === 0 && "rounded-l-full",
                  i === head.length - 1 && "rounded-r-full",
                )}
              >
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="[&_td]:border-b [&_td]:border-border [&_td]:px-3 [&_td]:py-3 [&_tr:last-child_td]:border-b-0">
          {children}
        </tbody>
      </table>
    </div>
  );
}

export function Empty({ text }: { text: string }) {
  return <p className="py-10 text-center text-body text-text-muted">{text}</p>;
}

/** Previous / Next with "Showing x–y of n". */
export function Pagination({
  page,
  pageSize,
  total,
  href,
}: {
  page: number;
  pageSize: number;
  total: number;
  href: (page: number) => string;
}) {
  const first = total === 0 ? 0 : (page - 1) * pageSize + 1;
  const last = Math.min(total, page * pageSize);
  const pages = Math.max(1, Math.ceil(total / pageSize));
  const link =
    "inline-flex h-10 items-center rounded-full border border-border px-4 font-medium text-ink hover:bg-surface-2";
  return (
    <div className="mt-4 flex flex-wrap items-center justify-between gap-3 text-label text-text-muted">
      <span>
        Showing {first}–{last} of {total}
      </span>
      <div className="flex gap-2">
        {page > 1 ? (
          <Link className={link} href={href(page - 1)}>
            Previous
          </Link>
        ) : (
          <span className={cn(link, "opacity-40")} aria-disabled>
            Previous
          </span>
        )}
        {page < pages ? (
          <Link className={link} href={href(page + 1)}>
            Next
          </Link>
        ) : (
          <span className={cn(link, "opacity-40")} aria-disabled>
            Next
          </span>
        )}
      </div>
    </div>
  );
}
