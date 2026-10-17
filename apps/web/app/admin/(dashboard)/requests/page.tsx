import Link from "next/link";
import { X } from "lucide-react";
import { requireAdmin } from "@/lib/admin/auth";
import { cn } from "@/lib/utils";
import {
  displayPlate,
  formatDate,
  formatDateTime,
  timeAgo,
} from "@/lib/format";
import { ActionButton } from "@/components/admin/action-button";
import {
  Empty,
  PageHeader,
  Panel,
  Pill,
  Table,
  TypePill,
} from "@/components/admin/ui";
import { decideRequest } from "../../actions";

const TABS = ["pending", "escalated", "approved", "rejected"] as const;
type Tab = (typeof TABS)[number];
const PURPOSE: Record<string, string> = {
  meeting: "Meeting",
  delivery: "Delivery",
  contractor: "Contractor work",
  interview: "Interview",
  other: "Other",
};

// A4 Requests: Pending · Escalated · Approved · Rejected; row opens A5 (drawer).
export default async function Requests({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string; id?: string }>;
}) {
  const sp = await searchParams;
  const tab: Tab = TABS.includes(sp.tab as Tab) ? (sp.tab as Tab) : "pending";
  const { supabase } = await requireAdmin();

  let q = supabase
    .from("passes")
    .select(
      "id, type, source, host_name, created_at, decided_at, escalated_at, reject_reason, people(full_name)",
    )
    .in("type", ["day", "week"]);
  const weekAgo = new Date(Date.now() - 7 * 86_400_000).toISOString();
  q =
    tab === "pending"
      ? q.eq("status", "pending")
      : tab === "escalated"
        ? q.eq("status", "pending").not("escalated_at", "is", null)
        : tab === "approved"
          ? q.eq("status", "approved").gte("decided_at", weekAgo)
          : q.eq("status", "rejected").gte("decided_at", weekAgo);
  const [{ data: rows }, { data: settings }] = await Promise.all([
    q
      .order(
        tab === "pending" || tab === "escalated" ? "created_at" : "decided_at",
        { ascending: tab === "pending" || tab === "escalated" },
      )
      .limit(200),
    supabase.from("settings").select("approval_timeout_minutes").single(),
  ]);
  const timeoutMs = (settings?.approval_timeout_minutes ?? 5) * 60_000;

  return (
    <div className="grid gap-6">
      <PageHeader
        title="Requests"
        subtitle="Visitor pass requests from the portal and the gates"
      />
      <nav
        aria-label="Request status"
        className="flex w-fit flex-wrap gap-1 rounded-full border border-border bg-surface p-1"
      >
        {TABS.map((t) => (
          <Link
            key={t}
            href={`/admin/requests?tab=${t}`}
            aria-current={t === tab ? "page" : undefined}
            className={cn(
              "rounded-full px-4 py-2 font-medium capitalize",
              t === tab ? "bg-ink text-brand" : "text-ink hover:bg-surface-2",
            )}
          >
            {t}
          </Link>
        ))}
      </nav>
      <Panel>
        {!rows?.length ? (
          <Empty
            text={
              tab === "pending"
                ? "Nothing waiting for approval."
                : `No ${tab} requests in the last 7 days.`
            }
          />
        ) : (
          <Table
            head={[
              "Visitor",
              "Visiting",
              "Pass",
              "Source",
              "Requested",
              tab === "rejected" ? "Reason" : "Age",
            ]}
            caption={`${tab} requests`}
          >
            {rows.map((r) => {
              const late =
                (tab === "pending" || tab === "escalated") &&
                Date.now() - new Date(r.created_at).getTime() > timeoutMs;
              return (
                <tr
                  key={r.id}
                  className={cn(sp.id === r.id && "bg-brand-soft")}
                >
                  <td>
                    <Link
                      href={`/admin/requests?tab=${tab}&id=${r.id}`}
                      className="font-medium text-ink hover:underline"
                    >
                      {(r.people as unknown as { full_name: string }).full_name}
                    </Link>
                  </td>
                  <td>{r.host_name ?? "—"}</td>
                  <td>
                    <TypePill type={r.type} />
                  </td>
                  <td>
                    {r.source === "gate" ? (
                      <Pill tone="brand" dot={false}>
                        Gate
                      </Pill>
                    ) : (
                      <Pill tone="info" dot={false}>
                        Web
                      </Pill>
                    )}
                  </td>
                  <td className="whitespace-nowrap">
                    {formatDateTime(r.created_at)}
                  </td>
                  <td>
                    {tab === "rejected" ? (
                      r.reject_reason
                    ) : (
                      <span
                        className={
                          late
                            ? "font-semibold text-warning"
                            : "text-text-muted"
                        }
                      >
                        {timeAgo(
                          tab === "approved"
                            ? (r.decided_at ?? r.created_at)
                            : r.created_at,
                        )}
                      </span>
                    )}
                  </td>
                </tr>
              );
            })}
          </Table>
        )}
      </Panel>
      {sp.id && (
        <RequestDrawer id={sp.id} closeHref={`/admin/requests?tab=${tab}`} />
      )}
    </div>
  );
}

type Detail = {
  pass_id: string;
  status: string;
  pass_type: string;
  source: string;
  full_name: string;
  id_number?: string;
  phone?: string;
  email?: string;
  plate?: string;
  host_name?: string;
  purpose?: string;
  requested_at: string;
  escalated_at?: string;
  decided_at?: string;
  reject_reason?: string;
  requested_by_name?: string;
  decided_by_name?: string;
  photo_paths?: string[];
  valid_from: string;
  valid_until: string;
};

// A5 Request detail: right drawer (480 px) with visitor, visit, ID photo, timeline, Approve / Reject.
async function RequestDrawer({
  id,
  closeHref,
}: {
  id: string;
  closeHref: string;
}) {
  const { supabase } = await requireAdmin();
  const { data, error } = await supabase.rpc("request_detail", {
    p_pass_id: id,
  });
  const d = data as Detail | null;
  const photos = d?.photo_paths?.length
    ? await Promise.all(
        d.photo_paths.map(
          async (p) =>
            (await supabase.storage.from("id-photos").createSignedUrl(p, 300))
              .data?.signedUrl,
        ),
      )
    : [];

  return (
    <aside
      aria-label="Request detail"
      className="fixed inset-y-0 right-0 z-20 flex w-full max-w-[480px] flex-col border-l border-border bg-surface shadow-[0_0_0_100vmax_color-mix(in_oklab,var(--ink)_25%,transparent)]"
    >
      <div className="flex items-center justify-between border-b border-border p-5">
        <h2 className="text-title font-semibold text-ink">Request</h2>
        <Link
          href={closeHref}
          aria-label="Close"
          className="rounded-full p-2 hover:bg-surface-2"
        >
          <X className="size-5" />
        </Link>
      </div>
      {error || !d ? (
        <p className="p-5 text-danger">This request could not be loaded.</p>
      ) : (
        <>
          <div className="grid flex-1 content-start gap-6 overflow-y-auto p-5">
            <section>
              <p className="text-title font-semibold text-ink">{d.full_name}</p>
              <dl className="mt-2 grid grid-cols-[120px_1fr] gap-y-1.5 text-label">
                <dt className="text-text-muted">ID number</dt>
                <dd>{d.id_number ?? "—"}</dd>
                <dt className="text-text-muted">Phone</dt>
                <dd>{d.phone ?? "—"}</dd>
                <dt className="text-text-muted">Email</dt>
                <dd className="break-all">{d.email ?? "—"}</dd>
                <dt className="text-text-muted">Vehicle</dt>
                <dd>{d.plate ? displayPlate(d.plate) : "—"}</dd>
              </dl>
            </section>
            <section>
              <h3 className="font-semibold text-ink">Visit</h3>
              <dl className="mt-2 grid grid-cols-[120px_1fr] gap-y-1.5 text-label">
                <dt className="text-text-muted">Visiting</dt>
                <dd>{d.host_name ?? "—"}</dd>
                <dt className="text-text-muted">Purpose</dt>
                <dd>{PURPOSE[d.purpose ?? ""] ?? d.purpose ?? "—"}</dd>
                <dt className="text-text-muted">Pass</dt>
                <dd>
                  {d.pass_type === "week" ? "One week" : "One day"} from{" "}
                  {formatDate(d.valid_from)}
                </dd>
                <dt className="text-text-muted">Source</dt>
                <dd>{d.source === "gate" ? "At the gate" : "Online"}</dd>
              </dl>
            </section>
            {photos.length > 0 && (
              <section>
                <h3 className="font-semibold text-ink">ID photo</h3>
                <div className="mt-2 flex flex-wrap gap-3">
                  {photos.map((url, i) =>
                    url ? (
                      <a
                        key={i}
                        href={url}
                        target="_blank"
                        rel="noreferrer"
                        className="block overflow-hidden rounded-2xl border border-border"
                        title="Open full size"
                      >
                        {/* eslint-disable-next-line @next/next/no-img-element -- short-lived signed link */}
                        <img
                          src={url}
                          alt={`ID photo ${i + 1} for ${d.full_name}`}
                          className="h-28 w-40 object-cover"
                        />
                      </a>
                    ) : null,
                  )}
                </div>
              </section>
            )}
            <section>
              <h3 className="font-semibold text-ink">Timeline</h3>
              <ol className="mt-2 grid gap-2 border-l-2 border-border pl-4 text-label">
                <li>
                  {d.source === "gate"
                    ? `Registered at the gate${d.requested_by_name ? ` by ${d.requested_by_name}` : ""}`
                    : "Requested online"}
                  <span className="block text-text-muted">
                    {formatDateTime(d.requested_at)}
                  </span>
                </li>
                {d.escalated_at && (
                  <li className="text-warning">
                    Escalated to admins
                    <span className="block text-text-muted">
                      {formatDateTime(d.escalated_at)}
                    </span>
                  </li>
                )}
                {d.decided_at && (
                  <li>
                    {d.status === "rejected"
                      ? "Rejected"
                      : d.status === "revoked"
                        ? "Revoked"
                        : "Approved"}
                    {d.decided_by_name ? ` by ${d.decided_by_name}` : ""}
                    {d.reject_reason ? `: ${d.reject_reason}` : ""}
                    <span className="block text-text-muted">
                      {formatDateTime(d.decided_at)}
                    </span>
                  </li>
                )}
              </ol>
            </section>
          </div>
          {d.status === "pending" && (
            <div className="flex flex-wrap gap-3 border-t border-border p-5">
              <ActionButton
                label="Approve"
                variant="primary"
                size="md"
                run={decideRequest.bind(null, d.pass_id, true, undefined)}
              />
              <ActionButton
                label="Reject"
                variant="danger"
                size="md"
                confirm={{
                  title: `Reject ${d.full_name}?`,
                  body: "The visitor sees this reason.",
                  action: "Reject request",
                }}
                field={{
                  name: "reason",
                  label: "Reason",
                  required: true,
                  placeholder: "e.g. Host is not available",
                }}
                run={async (reason) => {
                  "use server";
                  return decideRequest(d.pass_id, false, reason);
                }}
              />
            </div>
          )}
        </>
      )}
    </aside>
  );
}
