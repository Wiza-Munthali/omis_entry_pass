import Image from "next/image";

/** GHII logo with the product name, centred above portal forms. */
export function Brand({ subtitle }: { subtitle?: string }) {
  return (
    <header className="flex flex-col items-center text-center">
      <Image src="/logo.png" alt="GHII" width={112} height={112} priority />
      <h1 className="mt-6 text-display font-semibold text-ink">OMIS Entry</h1>
      {subtitle && <p className="mt-2 text-body text-text-muted">{subtitle}</p>}
    </header>
  );
}
