import Image from "next/image";

// Placeholder until the portal Welcome screen (P1) is built in Phase 3.
export default function Home() {
  return (
    <main className="flex min-h-dvh flex-col items-center justify-center gap-6 px-5">
      <Image src="/logo.png" alt="GHII" width={96} height={96} priority />
      <h1 className="text-display font-semibold text-ink">OMIS Entry</h1>
      <p className="text-body text-text-muted">Get your gate pass</p>
      <span className="rounded-full bg-brand-soft px-4 py-1 text-label font-medium text-brand-strong">
        Setup complete
      </span>
    </main>
  );
}
