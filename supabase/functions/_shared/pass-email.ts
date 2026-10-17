// Branded emails in one visual style (docs/SPEC.md → Emails): 600 px white card on the
// off-white background, plain-text fallback. The pass email embeds the QR inline
// (cid:pass-qr). No imports beyond tokens so this can be unit-tested anywhere.
import { colors } from "./tokens.ts";

export const QR_CONTENT_ID = "pass-qr";

export type PassType = "staff" | "day" | "week";

export type PassEmailInput = {
  fullName: string;
  passType: PassType;
  plate?: string | null;
  validFrom?: string | null; // ISO; shown for visitor passes
  validUntil: string; // ISO
  hostName?: string | null;
  passUrl: string;
};

export type RejectionEmailInput = {
  fullName: string;
  reason: string;
  hostName?: string | null;
  statusUrl: string;
};

const TYPE_LABEL: Record<PassType, string> = {
  staff: "Staff",
  day: "One-day visitor",
  week: "One-week visitor",
};

export function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

/** "BT4521" → "BT 4521", matching the pass page. */
export function displayPlate(plate: string): string {
  const match = /^([A-Z]+)(\d.*)$/.exec(plate);
  return match ? `${match[1]} ${match[2]}` : plate;
}

const TZ = "Africa/Blantyre";

/** "17 Oct 2027" in Africa/Blantyre, the site's time zone. */
export function formatLocalDate(iso: string): string {
  return new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", year: "numeric", timeZone: TZ }).format(
    new Date(iso),
  );
}

/**
 * Visitor validity as days: a day pass is "18 Oct 2026"; a week pass is
 * "18 Oct – 24 Oct 2026" (valid_until is the following midnight, so show the day before).
 */
export function formatValidity(passType: PassType, validFrom: string, validUntil: string): string {
  const lastDay = new Date(new Date(validUntil).getTime() - 1).toISOString();
  const first = formatLocalDate(validFrom);
  const last = formatLocalDate(lastDay);
  if (passType === "day" || first === last) return first;
  const shortFirst = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", timeZone: TZ }).format(
    new Date(validFrom),
  );
  return `${shortFirst} – ${last}`;
}

function layout(subject: string, rows: string): string {
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${escapeHtml(subject)}</title>
  </head>
  <body style="margin:0;padding:0;background:${colors.bg};font-family:Inter,Segoe UI,Helvetica,Arial,sans-serif;color:${colors.text};">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${colors.bg};padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:${colors.surface};border-radius:24px;overflow:hidden;">
            <tr><td style="height:8px;background:${colors.brand};font-size:0;line-height:0;">&nbsp;</td></tr>
${rows}
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function header(title: string, chip: string): string {
  return `            <tr>
              <td style="padding:28px 32px 8px;">
                <p style="margin:0;font-size:14px;line-height:20px;font-weight:600;color:${colors.brandStrong};">OMIS Entry</p>
                <h1 style="margin:8px 0 0;font-size:28px;line-height:34px;font-weight:600;color:${colors.ink};">${title}</h1>
                <p style="margin:12px 0 0;">${chip}</p>
              </td>
            </tr>`;
}

function chip(label: string, fg: string, bg: string): string {
  return `<span style="display:inline-block;padding:4px 14px;border-radius:999px;background:${bg};font-size:14px;line-height:20px;font-weight:500;color:${fg};">${label}</span>`;
}

function details(rows: [label: string, value: string][]): string {
  const cells = rows
    .map(
      ([label, value], i) =>
        `<tr><td style="padding:12px 0;font-size:14px;color:${colors.textMuted};${i ? `border-top:1px solid ${colors.border};` : ""}">${label}</td><td align="right" style="padding:12px 0;font-size:16px;font-weight:600;color:${colors.ink};${i ? `border-top:1px solid ${colors.border};` : ""}">${value}</td></tr>`,
    )
    .join("");
  return `            <tr>
              <td style="padding:0 32px 8px;">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-top:1px solid ${colors.border};">${cells}</table>
              </td>
            </tr>`;
}

function paragraph(html: string): string {
  return `            <tr>
              <td style="padding:16px 32px 8px;">
                <p style="margin:0;font-size:16px;line-height:24px;">${html}</p>
              </td>
            </tr>`;
}

function button(label: string, href: string): string {
  return `            <tr>
              <td align="center" style="padding:16px 32px 32px;">
                <a href="${escapeHtml(href)}" style="display:inline-block;padding:16px 32px;border-radius:999px;background:${colors.ink};color:${colors.brand};font-size:16px;font-weight:600;text-decoration:none;">${label}</a>
              </td>
            </tr>`;
}

/** Staff pass issued / visitor pass approved: QR, validity, plate, gate instructions. */
export function renderPassEmail(input: PassEmailInput) {
  const type = TYPE_LABEL[input.passType];
  const isVisitor = input.passType !== "staff";
  const validity =
    isVisitor && input.validFrom
      ? formatValidity(input.passType, input.validFrom, input.validUntil)
      : formatLocalDate(input.validUntil);
  const validLabel = isVisitor && input.validFrom ? "Valid" : "Valid until";

  const rows: [string, string][] = [];
  if (isVisitor && input.hostName) rows.push(["Visiting", escapeHtml(input.hostName)]);
  if (input.plate) rows.push(["Vehicle", escapeHtml(displayPlate(input.plate))]);
  rows.push([validLabel, validity]);

  const subject = isVisitor
    ? `Your visitor pass is approved, ${input.fullName}`
    : `Your OMIS Entry pass, ${input.fullName}`;
  const instructions = isVisitor
    ? "Show this code to the guard when you arrive at the gate, and again when you leave. Bring the ID you used on your request."
    : "Show this code to the guard at the gate. They scan it when you arrive and when you leave.";

  const html = layout(
    subject,
    [
      header(escapeHtml(input.fullName), chip(type, colors.ink, colors.surface2)),
      `            <tr>
              <td align="center" style="padding:24px 32px;">
                <img src="cid:${QR_CONTENT_ID}" width="280" height="280" alt="Your gate pass QR code" style="display:block;width:280px;height:280px;" />
              </td>
            </tr>`,
      details(rows),
      paragraph(instructions),
      button("Open my pass", input.passUrl),
    ].join("\n"),
  );

  const text = [
    `OMIS Entry — ${input.fullName}`,
    `${type} pass${input.plate ? `, vehicle ${displayPlate(input.plate)}` : ""}`,
    ...(isVisitor && input.hostName ? [`Visiting: ${input.hostName}`] : []),
    `${validLabel}: ${validity}`,
    "",
    instructions,
    `Open your pass: ${input.passUrl}`,
  ].join("\n");

  return { subject, html, text };
}

/** Visitor request rejected: the reason and a link back to the status page. */
export function renderRejectionEmail(input: RejectionEmailInput) {
  const subject = `Your visit request was not approved, ${input.fullName}`;
  const host = input.hostName ? ` to ${escapeHtml(input.hostName)}` : "";
  const html = layout(
    subject,
    [
      header(escapeHtml(input.fullName), chip("Not approved", colors.danger, colors.dangerSoft)),
      paragraph(`Reception could not approve your visit${host}.`),
      details([["Reason", escapeHtml(input.reason)]]),
      paragraph("If you think this is a mistake, contact the person you are visiting or ask the guard at the gate."),
      button("View request", input.statusUrl),
    ].join("\n"),
  );
  const text = [
    `OMIS Entry — ${input.fullName}`,
    `Reception could not approve your visit${input.hostName ? ` to ${input.hostName}` : ""}.`,
    `Reason: ${input.reason}`,
    "",
    "If you think this is a mistake, contact the person you are visiting or ask the guard at the gate.",
    `View request: ${input.statusUrl}`,
  ].join("\n");
  return { subject, html, text };
}

export type ApprovalRequestEmailInput = {
  fullName: string;
  passType: PassType;
  hostName?: string | null;
  source: "web" | "gate";
  requestedBy?: string | null;
  requestedAt: string; // ISO
  validFrom: string;
  validUntil: string;
  escalatedMinutes?: number | null;
};

/** "10:42" in Africa/Blantyre. */
function formatLocalTime(iso: string): string {
  return new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", hour12: false, timeZone: TZ }).format(
    new Date(iso),
  );
}

/** New request for reception (or, when escalated, for admins). */
export function renderApprovalRequestEmail(input: ApprovalRequestEmailInput) {
  const escalated = input.escalatedMinutes != null;
  const subject = escalated
    ? `Waiting ${input.escalatedMinutes} min for approval: ${input.fullName}`
    : `New visitor request: ${input.fullName}`;
  const type = TYPE_LABEL[input.passType];
  const source =
    input.source === "gate"
      ? `At the gate${input.requestedBy ? ` (registered by ${escapeHtml(input.requestedBy)})` : ""}`
      : "Online request";
  const rows: [string, string][] = [
    ["Visiting", escapeHtml(input.hostName ?? "—")],
    ["Pass", `${type}, ${formatValidity(input.passType, input.validFrom, input.validUntil)}`],
    ["Requested", `${formatLocalTime(input.requestedAt)} · ${source}`],
  ];
  const lead = escalated
    ? `No one has approved this request yet. ${input.source === "gate" ? "The visitor is waiting at the gate." : ""}`.trim()
    : input.source === "gate"
      ? "A visitor is waiting at the gate."
      : "A visitor has asked for a pass.";

  const html = layout(
    subject,
    [
      header(escapeHtml(input.fullName), chip(escalated ? "Waiting" : "Pending", colors.warning, colors.warningSoft)),
      paragraph(lead),
      details(rows),
      paragraph("Open the OMIS Entry gate app and go to <strong>Approvals</strong> to approve or reject it."),
    ].join("\n") + "\n            <tr><td style=\"height:16px\"></td></tr>",
  );
  const text = [
    subject,
    lead,
    `Visiting: ${input.hostName ?? "—"}`,
    `Pass: ${type}, ${formatValidity(input.passType, input.validFrom, input.validUntil)}`,
    `Requested: ${formatLocalTime(input.requestedAt)} (${input.source === "gate" ? "at the gate" : "online"})`,
    "",
    "Open the OMIS Entry gate app → Approvals to approve or reject it.",
  ].join("\n");
  return { subject, html, text };
}
