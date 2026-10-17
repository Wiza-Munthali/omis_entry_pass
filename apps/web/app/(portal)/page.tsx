import Image from "next/image";
import Link from "next/link";
import { ArrowRight } from "lucide-react";
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
          illustration="/illustrations/staff-pass.webp"
          tint="bg-brand-soft"
        />
        <ChoiceCard
          href="/visit"
          title="I'm visiting"
          text="Request a visitor pass"
          illustration="/illustrations/visitor-pass.webp"
          tint="bg-warning-soft"
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
  illustration,
  tint,
}: {
  href: string;
  title: string;
  text: string;
  illustration: string;
  tint: string;
}) {
  return (
    <Link
      href={href}
      className="group block rounded-card bg-surface p-3 outline-none focus-visible:ring-[3px] focus-visible:ring-brand/40"
    >
      <div
        className={cn(
          "relative flex min-h-36 items-center gap-2 rounded-card p-5",
          tint,
        )}
      >
        {/* Decorative: the title says what the card is. The artwork has its own margin. */}
        <Image
          src={illustration}
          alt=""
          width={120}
          height={120}
          priority
          className="-my-3 -ml-4 size-22 shrink-0 min-[360px]:-my-4 min-[360px]:size-30"
        />
        <span className="grid gap-1">
          <span className="text-title font-semibold text-ink">{title}</span>
          {/* Room for the arrow button in the bottom-right corner. */}
          <span className="pr-12 text-body text-text-muted">{text}</span>
        </span>
        <span className="absolute right-4 bottom-4 inline-flex size-12 items-center justify-center rounded-full bg-ink text-brand transition-transform group-hover:translate-x-0.5">
          <ArrowRight className="size-5" aria-hidden />
        </span>
      </div>
    </Link>
  );
}
