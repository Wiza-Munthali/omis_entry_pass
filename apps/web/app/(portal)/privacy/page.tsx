import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { ScreenHeader } from "@/components/portal/screen-header";

export const metadata: Metadata = { title: "Privacy notice · OMIS Entry" };

type Notice = {
  org_name: string;
  privacy_contact: string | null;
  id_photo_retention_days: number;
  request_retention_days: number;
  rate_limit_retention_hours: number;
};

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Privacy notice (Phase 9). Retention periods come from the live settings, so the page
// always matches what the system actually does.
export default async function PrivacyPage() {
  const supabase = await createClient();
  const { data } = await supabase.rpc("privacy_notice");
  const n: Notice = data ?? {
    org_name: "GHII",
    privacy_contact: null,
    id_photo_retention_days: 30,
    request_retention_days: 90,
    rate_limit_retention_hours: 24,
  };
  const org = n.org_name;
  const contact = n.privacy_contact?.trim();

  return (
    <>
      <ScreenHeader backHref="/" />
      <h1 className="mt-8 text-display font-semibold text-ink">
        Privacy notice
      </h1>
      <p className="mt-2 text-body text-text-muted">
        How {org} uses your details when you come through its gates.
      </p>

      <div className="mt-8 grid gap-4">
        <Section title="What we collect">
          <ul className="grid list-disc gap-2 pl-5">
            <li>
              <strong className="font-semibold text-ink">Visitors:</strong> your
              name, phone number, email (if you give one), ID number, vehicle
              plate, who you are visiting and why, and the dates of your visit.
              If you arrive without a request, the guard may take a photo of
              your ID.
            </li>
            <li>
              <strong className="font-semibold text-ink">Staff:</strong> your
              work email, name, ID number and vehicle plate.
            </li>
            <li>
              <strong className="font-semibold text-ink">
                Each time you pass a gate:
              </strong>{" "}
              the time you came in and left, the gate, and who scanned your
              pass.
            </li>
          </ul>
        </Section>

        <Section title="Why">
          <p>
            To decide on visitor requests, check passes at the gate, know who is
            on site in an emergency, and look into security incidents. We do not
            use your details for marketing and we do not sell them.
          </p>
        </Section>

        <Section title="Who can see it">
          <p>
            Reception and the system&apos;s administrators. Guards see only what
            they need at the gate: your name, pass type, plate and whether your
            pass is valid. The companies that host the system, send our emails
            and report technical errors process data for us; error reports have
            names, phone numbers, emails and pass codes removed.
          </p>
        </Section>

        <Section title="How long we keep it">
          <ul className="grid list-disc gap-2 pl-5">
            <li>
              ID photos are deleted after {n.id_photo_retention_days} days.
            </li>
            <li>
              If your request is not approved, your contact and visit details
              are removed after {n.request_retention_days} days.
            </li>
            <li>
              To stop misuse of the request form, we keep your phone number and
              a scrambled copy of your internet address for{" "}
              {n.rate_limit_retention_hours} hours.
            </li>
            <li>
              Approved passes and the record of entries and exits are kept as
              the site&apos;s security log.
            </li>
          </ul>
        </Section>

        <Section title="Your rights">
          <p>
            You can ask to see the details we hold about you, have them
            corrected, or have them deleted when we no longer need them, as
            Malawi&apos;s data protection law allows.{" "}
            {contact ? (
              <>
                Contact{" "}
                {EMAIL.test(contact) ? (
                  <a
                    href={`mailto:${contact}`}
                    className="font-medium text-brand-strong hover:underline"
                  >
                    {contact}
                  </a>
                ) : (
                  <span className="font-medium text-ink">{contact}</span>
                )}
                .
              </>
            ) : (
              <>Ask at reception.</>
            )}
          </p>
        </Section>
      </div>
    </>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="rounded-card bg-surface p-5 text-body text-text">
      <h2 className="mb-2 text-title font-semibold text-ink">{title}</h2>
      {children}
    </section>
  );
}
