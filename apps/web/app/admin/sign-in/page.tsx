import Image from "next/image";
import { DoorOpen } from "lucide-react";
import { SignInForm } from "./sign-in-form";

export const metadata = { title: "Admin sign in · OMIS Entry" };

// A1 Sign in: white panel with the form, teal panel with the line "Every entry, on record".
export default async function AdminSignIn({
  searchParams,
}: {
  searchParams: Promise<{ denied?: string }>;
}) {
  const { denied } = await searchParams;
  return (
    <main className="grid min-h-dvh bg-surface lg:grid-cols-2">
      <section className="flex flex-col justify-center px-6 py-12 sm:px-16">
        <div className="mx-auto w-full max-w-sm">
          <div className="flex items-center gap-3">
            <Image src="/logo.png" alt="GHII" width={56} height={56} priority />
            <span className="text-title font-semibold text-ink">
              OMIS Entry
            </span>
          </div>
          <h1 className="mt-10 text-display font-semibold text-ink">
            Admin sign in
          </h1>
          <p className="mt-1 text-body text-text-muted">
            We&apos;ll email you a 6-digit code.
          </p>
          {denied && (
            <p
              role="alert"
              className="mt-4 rounded-card bg-danger-soft px-4 py-3 text-label font-medium text-danger"
            >
              This dashboard is for admins. Signed-in staff can use the portal;
              guards and reception use the gate app.
            </p>
          )}
          <SignInForm />
        </div>
      </section>
      <section
        className="hidden flex-col items-center justify-center gap-6 bg-brand p-16 lg:flex"
        aria-hidden
      >
        <div className="flex size-48 items-center justify-center rounded-full bg-brand-soft">
          <DoorOpen className="size-24 text-ink" strokeWidth={1.25} />
        </div>
        <p className="text-display font-semibold text-ink">
          Every entry, on record
        </p>
      </section>
    </main>
  );
}
