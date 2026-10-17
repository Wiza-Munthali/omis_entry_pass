import Image from "next/image";
import Link from "next/link";
import { redirect } from "next/navigation";
import { CalendarDays, UserRound } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { displayPlate, formatDate } from "@/lib/format";
import { Chip } from "@/components/ui/chip";
import { Notice } from "@/components/portal/notice";
import { QrCode } from "@/components/portal/qr-code";
import { ScreenHeader } from "@/components/portal/screen-header";
import { buttonVariants } from "@/components/ui/button";
import { EmailPassButton } from "./email-pass-button";
import { InstallButton } from "./install-button";
import { ServiceWorker } from "./service-worker";
import { SignOutButton } from "./sign-out-button";

export const dynamic = "force-dynamic";

function initials(name: string) {
  const parts = name.trim().split(/\s+/);
  return (
    (parts[0]?.[0] ?? "") + (parts.length > 1 ? parts[parts.length - 1][0] : "")
  ).toUpperCase();
}

// P5 Staff pass
export default async function PassPage({
  searchParams,
}: {
  searchParams: Promise<{ emailed?: string }>;
}) {
  const { emailed } = await searchParams;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/staff");

  const { data: pass } = await supabase
    .from("passes")
    .select(
      "id, status, qr_token, valid_until, people(full_name), vehicles(plate)",
    )
    .eq("type", "staff")
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (!pass) redirect("/staff/details");

  const name = (pass.people as unknown as { full_name: string }).full_name;
  const plate = (pass.vehicles as unknown as { plate: string } | null)?.plate;
  const revoked = pass.status === "revoked";
  const expired =
    !revoked &&
    (pass.status === "expired" || new Date(pass.valid_until) <= new Date());
  const active = !revoked && !expired;

  return (
    <>
      <ServiceWorker />
      <ScreenHeader title="Staff pass" backHref="/" />

      <div className="mt-6 grid gap-4">
        {emailed === "1" && active && (
          <Notice tone="success">
            Saved. We&apos;ve emailed you a copy of your pass.
          </Notice>
        )}
        {emailed === "0" && active && (
          <Notice tone="warning">
            Your pass is ready, but we couldn&apos;t email it. Try “Email me my
            pass”.
          </Notice>
        )}
        {revoked && (
          <Notice tone="danger">
            This pass has been revoked. Please contact reception.
          </Notice>
        )}
        {expired && (
          <Notice tone="warning">
            This pass expired on {formatDate(pass.valid_until)}. Renew it below.
          </Notice>
        )}

        <article className="overflow-hidden rounded-card bg-surface">
          <div className="flex h-24 items-center bg-brand-soft px-6">
            <Image src="/logo.png" alt="GHII" width={64} height={64} />
          </div>
          <div className="p-6">
            <div className="flex items-center gap-4">
              <span className="inline-flex size-16 shrink-0 items-center justify-center rounded-full bg-brand-soft text-title font-semibold text-brand-strong">
                {initials(name)}
              </span>
              <div className="grid gap-2">
                <h2 className="text-title font-semibold text-ink">{name}</h2>
                <div className="flex flex-wrap gap-2">
                  <Chip className="bg-brand-soft text-brand-strong">
                    <UserRound aria-hidden /> Staff
                  </Chip>
                  {revoked && <Chip tone="danger">Revoked</Chip>}
                  {expired && <Chip tone="warning">Expired</Chip>}
                </div>
              </div>
            </div>

            {active ? (
              <div className="mx-auto mt-6 w-full max-w-[280px]">
                <QrCode
                  value={pass.qr_token}
                  label={`Gate pass QR code for ${name}`}
                />
              </div>
            ) : (
              <div className="mx-auto mt-6 flex aspect-square w-full max-w-[280px] items-center justify-center rounded-card bg-surface-2 px-6 text-center text-body text-text-muted">
                This pass can&apos;t be used at the gate.
              </div>
            )}

            <div className="mt-4 grid justify-items-center gap-1 text-center">
              {plate && (
                <p className="text-display font-semibold text-ink">
                  {displayPlate(plate)}
                </p>
              )}
              <p className="inline-flex items-center gap-2 text-body text-text-muted">
                <CalendarDays className="size-5" aria-hidden />
                Valid until {formatDate(pass.valid_until)}
              </p>
            </div>
          </div>
        </article>

        {active && <EmailPassButton />}
        {active && <InstallButton />}
        {expired && (
          <Link href="/staff/details" className={buttonVariants()}>
            Renew my pass
          </Link>
        )}

        <div className="mt-2 flex items-center justify-center gap-6 text-label">
          {!revoked && (
            <Link
              href="/staff/details"
              className="font-medium text-brand-strong hover:underline"
            >
              Edit details
            </Link>
          )}
          <SignOutButton />
        </div>
      </div>
    </>
  );
}
