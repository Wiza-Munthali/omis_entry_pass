import Link from "next/link";
import { ArrowRight, IdCard, UserPlus } from "lucide-react";
import { cn } from "@/lib/utils";
import { Brand } from "@/components/portal/brand";

// P1 Welcome
export default function WelcomePage() {
  return (
    <>
      <div className="pt-8">
        <Brand subtitle="Get your gate pass" />
      </div>

      <nav
        className="mt-10 grid gap-4"
        aria-label="Choose how you are coming in"
      >
        <ChoiceCard
          href="/staff"
          title="I work here"
          text="Get your staff pass"
          icon={<IdCard />}
          tint="bg-brand-soft"
          iconTone="bg-surface text-brand-strong"
        />
        <ChoiceCard
          href="/visit"
          title="I'm visiting"
          text="Request a visitor pass"
          icon={<UserPlus />}
          tint="bg-warning-soft"
          iconTone="bg-surface text-warning"
        />
      </nav>

      <p className="mt-10 text-center text-body text-text-muted">
        Already have a pass?{" "}
        <Link
          href="/pass"
          className="inline-flex items-center gap-1 font-medium text-brand-strong hover:underline"
        >
          View it <ArrowRight className="size-4" aria-hidden />
        </Link>
      </p>

      <p className="mt-auto pt-10 text-center text-label text-text-muted">
        <Link href="/privacy" className="hover:underline">
          Privacy notice
        </Link>
      </p>
    </>
  );
}

function ChoiceCard({
  href,
  title,
  text,
  icon,
  tint,
  iconTone,
}: {
  href: string;
  title: string;
  text: string;
  icon: React.ReactNode;
  tint: string;
  iconTone: string;
}) {
  return (
    <Link
      href={href}
      className="group block rounded-card bg-surface p-3 outline-none focus-visible:ring-[3px] focus-visible:ring-brand/40"
    >
      <div
        className={cn(
          "relative flex min-h-36 items-center gap-4 rounded-card p-5",
          tint,
        )}
      >
        <span
          className={cn(
            "inline-flex size-14 shrink-0 items-center justify-center rounded-full [&_svg]:size-7",
            iconTone,
          )}
        >
          {icon}
        </span>
        <span className="grid gap-1 pr-12">
          <span className="text-title font-semibold text-ink">{title}</span>
          <span className="text-body text-text-muted">{text}</span>
        </span>
        <span className="absolute right-4 bottom-4 inline-flex size-12 items-center justify-center rounded-full bg-ink text-brand transition-transform group-hover:translate-x-0.5">
          <ArrowRight className="size-5" aria-hidden />
        </span>
      </div>
    </Link>
  );
}
