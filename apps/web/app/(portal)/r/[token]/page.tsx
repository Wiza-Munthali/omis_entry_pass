import type { Metadata } from "next";
import { notFound } from "next/navigation";
import {
  CalendarDays,
  CircleCheck,
  CircleX,
  Clock,
  Car,
  MapPin,
  Ticket,
  UserRound,
} from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import {
  displayPlate,
  formatDate,
  formatDateTime,
  formatValidity,
} from "@/lib/format";
import { Chip } from "@/components/ui/chip";
import { QrCode } from "@/components/portal/qr-code";
import { LiveStatus } from "./live-status";

export const dynamic = "force-dynamic";

// The URL is the visitor's secret: keep it out of search engines and Referer headers.
export const metadata: Metadata = {
  title: "Visitor pass request · OMIS Entry",
  robots: { index: false, follow: false },
  referrer: "no-referrer",
};

type RequestStatus = {
  status: "pending" | "approved" | "rejected" | "revoked" | "expired";
  full_name: string;
  pass_type: "day" | "week";
  host_name?: string;
  plate?: string;
  valid_from: string;
  valid_until: string;
  requested_at: string;
  decided_at?: string;
  reject_reason?: string;
  qr_token?: string;
};

const TYPE_LABEL = { day: "One day", week: "One week" } as const;

// P9 Request status
export default async function RequestStatusPage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;
  const supabase = await createClient();
  const { data } = await supabase.rpc("get_request_status", {
    p_status_token: token,
  });
  if (!data) notFound();
  const r = data as RequestStatus;

  return (
    <>
      <header className="flex min-h-12 items-center justify-center">
        <h1 className="text-title font-semibold text-ink">
          Visitor pass request
        </h1>
      </header>

      <article className="mt-6 overflow-hidden rounded-card bg-surface">
        {r.status === "approved" && r.qr_token ? (
          <Approved r={r} qrToken={r.qr_token} />
        ) : (
          <Hero r={r} />
        )}

        <dl className="grid gap-4 border-t border-border p-6">
          <Detail icon={<UserRound />} label="Visitor" value={r.full_name} />
          {r.host_name && (
            <Detail icon={<MapPin />} label="Visiting" value={r.host_name} />
          )}
          <Detail
            icon={<Ticket />}
            label="Pass type"
            value={TYPE_LABEL[r.pass_type]}
          />
          <Detail
            icon={<CalendarDays />}
            label={r.pass_type === "day" ? "Date" : "Dates"}
            value={formatValidity(r.pass_type, r.valid_from, r.valid_until)}
          />
          {r.plate && (
            <Detail
              icon={<Car />}
              label="Vehicle"
              value={displayPlate(r.plate)}
            />
          )}
          <Detail
            icon={<Clock />}
            label="Requested"
            value={formatDateTime(r.requested_at)}
          />
        </dl>
      </article>

      {r.status === "pending" && (
        <div className="mt-6">
          <LiveStatus token={token} />
        </div>
      )}
    </>
  );
}

function Hero({ r }: { r: RequestStatus }) {
  const view = {
    pending: {
      chip: <Chip tone="warning">● Pending</Chip>,
      icon: (
        <Clock className="size-14 animate-[pulse_2.5s_ease-in-out_infinite] text-warning" />
      ),
      tint: "bg-warning-soft",
      title: "Waiting for reception to approve",
      text: "Keep this page open or check your email. It updates by itself.",
    },
    rejected: {
      chip: <Chip tone="danger">Not approved</Chip>,
      icon: <CircleX className="size-14 text-danger" />,
      tint: "bg-danger-soft",
      title: "Your request was not approved",
      text: r.reject_reason
        ? `Reason: ${r.reject_reason}`
        : "Please contact the person you are visiting.",
    },
    expired: {
      chip: <Chip tone="info">Expired</Chip>,
      icon: <CalendarDays className="size-14 text-info" />,
      tint: "bg-info-soft",
      title: "This pass has expired",
      text: `It was valid until ${formatDate(new Date(new Date(r.valid_until).getTime() - 1).toISOString())}. Request a new pass for another visit.`,
    },
    revoked: {
      chip: <Chip tone="danger">Revoked</Chip>,
      icon: <CircleX className="size-14 text-danger" />,
      tint: "bg-danger-soft",
      title: "This pass has been cancelled",
      text: "Please contact reception.",
    },
    approved: {
      chip: <Chip tone="success">Approved</Chip>,
      icon: <CircleCheck className="size-14 text-success" />,
      tint: "bg-success-soft",
      title: "Approved",
      text: "",
    },
  }[r.status];

  return (
    <div
      className="grid justify-items-center gap-4 px-6 pt-8 pb-6 text-center"
      role="status"
    >
      {view.chip}
      <div
        className={`flex size-32 items-center justify-center rounded-full ${view.tint}`}
      >
        {view.icon}
      </div>
      <h2 className="text-display font-semibold text-ink">{view.title}</h2>
      {view.text && <p className="text-body text-text-muted">{view.text}</p>}
    </div>
  );
}

function Approved({ r, qrToken }: { r: RequestStatus; qrToken: string }) {
  return (
    <div
      className="grid justify-items-center gap-4 px-6 pt-8 pb-6 text-center"
      role="status"
    >
      <Chip tone="success">
        <CircleCheck aria-hidden /> Approved
      </Chip>
      <h2 className="text-display font-semibold text-ink">
        Your pass is ready
      </h2>
      <div className="w-full max-w-[280px]">
        <QrCode
          value={qrToken}
          label={`Visitor pass QR code for ${r.full_name}`}
        />
      </div>
      <p className="text-body text-text-muted">
        Show this code to the guard when you arrive and when you leave.
        We&apos;ve also emailed it to you.
      </p>
    </div>
  );
}

function Detail({
  icon,
  label,
  value,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
}) {
  return (
    <div className="flex items-center gap-4">
      <span className="inline-flex size-11 shrink-0 items-center justify-center rounded-full bg-surface-2 text-ink [&_svg]:size-5">
        {icon}
      </span>
      <div className="grid">
        <dt className="text-label text-text-muted">{label}</dt>
        <dd className="text-body font-medium text-ink">{value}</dd>
      </div>
    </div>
  );
}
