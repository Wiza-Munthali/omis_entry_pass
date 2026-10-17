import Link from "next/link";
import { requireAdmin } from "@/lib/admin/auth";
import { cn } from "@/lib/utils";
import { displayPlate, formatDate } from "@/lib/format";
import { ActionButton } from "@/components/admin/action-button";
import { QrDialog } from "@/components/admin/qr-dialog";
import { QrCode } from "@/components/portal/qr-code";
import {
  Empty,
  PageHeader,
  Panel,
  Pill,
  Table,
  TypePill,
} from "@/components/admin/ui";
import { extendPass, resendPass, revokePass } from "../../actions";

const STATUS = {
  approved: <Pill tone="success">Active</Pill>,
  pending: <Pill tone="warning">Pending</Pill>,
  rejected: <Pill tone="danger">Rejected</Pill>,
  revoked: <Pill tone="danger">Revoked</Pill>,
  expired: <Pill tone="neutral">Expired</Pill>,
} as const;

// A6 Passes: Staff · Visitors; View QR, Resend, Extend, Revoke (confirm).
export default async function Passes({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string; q?: string }>;
}) {
  const sp = await searchParams;
  const tab = sp.tab === "visitors" ? "visitors" : "staff";
  const q = (sp.q ?? "").trim();
  const { supabase } = await requireAdmin();

  let query = supabase
    .from("passes")
    .select(
      "id, type, status, qr_token, valid_from, valid_until, people!inner(full_name, email), vehicles(plate)",
    )
    .in("type", tab === "staff" ? ["staff"] : ["day", "week"])
    .neq("status", "pending");
  if (q) query = query.ilike("people.full_name", `%${q}%`);
  const { data: passes } = await query
    .order("valid_until", { ascending: false })
    .limit(200);

  return (
    <div className="grid gap-6">
      <PageHeader
        title="Passes"
        subtitle="Staff passes and approved visitor passes"
      />
      <div className="flex flex-wrap items-center gap-3">
        <nav
          aria-label="Pass type"
          className="flex gap-1 rounded-full border border-border bg-surface p-1"
        >
          {(["staff", "visitors"] as const).map((t) => (
            <Link
              key={t}
              href={`/admin/passes?tab=${t}`}
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
        <form role="search">
          <input type="hidden" name="tab" value={tab} />
          <input
            name="q"
            defaultValue={q}
            placeholder="Search holder…"
            aria-label="Search holder"
            className="h-11 rounded-full border border-border bg-surface px-4 outline-none focus-visible:border-brand"
          />
        </form>
      </div>
      <Panel>
        {!passes?.length ? (
          <Empty text="No passes match." />
        ) : (
          <Table
            head={["Holder", "Type", "Plate", "Valid", "Status", "Actions"]}
            caption={`${tab} passes`}
          >
            {passes.map((p) => {
              const person = p.people as unknown as {
                full_name: string;
                email: string | null;
              };
              const status =
                p.status === "approved" && new Date(p.valid_until) <= new Date()
                  ? "expired"
                  : p.status;
              return (
                <tr key={p.id}>
                  <td>
                    <p className="font-medium text-ink">{person.full_name}</p>
                    <p className="text-caption text-text-muted">
                      {person.email ?? ""}
                    </p>
                  </td>
                  <td>
                    <TypePill type={p.type} />
                  </td>
                  <td>
                    {(p.vehicles as unknown as { plate: string } | null)?.plate
                      ? displayPlate(
                          (p.vehicles as unknown as { plate: string }).plate,
                        )
                      : "—"}
                  </td>
                  <td className="whitespace-nowrap">
                    {formatDate(p.valid_from)} –{" "}
                    {formatDate(
                      new Date(
                        new Date(p.valid_until).getTime() - 1,
                      ).toISOString(),
                    )}
                  </td>
                  <td>{STATUS[status as keyof typeof STATUS]}</td>
                  <td>
                    <div className="flex flex-wrap items-start gap-2">
                      {status === "approved" && (
                        <QrDialog name={person.full_name}>
                          <QrCode
                            value={p.qr_token}
                            label={`QR code for ${person.full_name}`}
                          />
                        </QrDialog>
                      )}
                      {status === "approved" && (
                        <ActionButton
                          label="Resend"
                          run={resendPass.bind(null, p.id)}
                        />
                      )}
                      {(status === "approved" || status === "expired") && (
                        <ActionButton
                          label="Extend"
                          confirm={{
                            title: `Extend ${person.full_name}'s pass`,
                            action: "Extend",
                          }}
                          field={{
                            name: "days",
                            label: "By",
                            options: (p.type === "staff"
                              ? [365, 90, 30]
                              : [7, 1, 30]
                            ).map((d) => ({
                              value: String(d),
                              label: `${d} days`,
                            })),
                          }}
                          run={async (days) => {
                            "use server";
                            return extendPass(p.id, Number(days));
                          }}
                        />
                      )}
                      {status === "approved" && (
                        <ActionButton
                          label="Revoke"
                          variant="danger"
                          confirm={{
                            title: `Revoke ${person.full_name}'s pass?`,
                            body: "It stops working at the gate immediately and the holder is emailed.",
                            action: "Revoke pass",
                          }}
                          field={{
                            name: "reason",
                            label: "Reason (for the audit log)",
                            placeholder: "e.g. Left the organisation",
                          }}
                          run={async (reason) => {
                            "use server";
                            return revokePass(p.id, reason ?? "");
                          }}
                        />
                      )}
                    </div>
                  </td>
                </tr>
              );
            })}
          </Table>
        )}
      </Panel>
    </div>
  );
}
