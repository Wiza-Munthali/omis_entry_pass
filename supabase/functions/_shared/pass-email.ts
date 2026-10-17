// Branded "here is your pass" email: 600 px card with the QR code inline (cid:pass-qr)
// and a plain-text fallback. No imports beyond tokens so it can be unit-tested anywhere.
import { colors } from "./tokens.ts";

export const QR_CONTENT_ID = "pass-qr";

export type PassEmailInput = {
  fullName: string;
  passType: "staff" | "day" | "week";
  plate?: string | null;
  validUntil: string; // ISO timestamp
  passUrl: string;
};

const TYPE_LABEL: Record<PassEmailInput["passType"], string> = {
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

/** "17 Oct 2027" in Africa/Blantyre, the site's time zone. */
export function formatLocalDate(iso: string): string {
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
    timeZone: "Africa/Blantyre",
  }).format(new Date(iso));
}

export function renderPassEmail(input: PassEmailInput) {
  const name = escapeHtml(input.fullName);
  const type = TYPE_LABEL[input.passType];
  const validUntil = formatLocalDate(input.validUntil);
  const plate = input.plate ? escapeHtml(input.plate) : null;
  const url = escapeHtml(input.passUrl);

  const subject = `Your OMIS Entry pass, ${input.fullName}`;

  const html = `<!doctype html>
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
            <tr>
              <td style="padding:28px 32px 8px;">
                <p style="margin:0;font-size:14px;line-height:20px;font-weight:600;color:${colors.brandStrong};">OMIS Entry</p>
                <h1 style="margin:8px 0 0;font-size:28px;line-height:34px;font-weight:600;color:${colors.ink};">${name}</h1>
                <p style="margin:12px 0 0;">
                  <span style="display:inline-block;padding:4px 14px;border-radius:999px;background:${colors.surface2};font-size:14px;line-height:20px;font-weight:500;color:${colors.ink};">${type}</span>
                </p>
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:24px 32px;">
                <img src="cid:${QR_CONTENT_ID}" width="280" height="280" alt="Your gate pass QR code" style="display:block;width:280px;height:280px;" />
              </td>
            </tr>
            <tr>
              <td style="padding:0 32px 8px;">
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-top:1px solid ${colors.border};">
                  ${
                    plate
                      ? `<tr><td style="padding:12px 0;font-size:14px;color:${colors.textMuted};">Vehicle</td><td align="right" style="padding:12px 0;font-size:16px;font-weight:600;color:${colors.ink};">${plate}</td></tr>`
                      : ""
                  }
                  <tr><td style="padding:12px 0;font-size:14px;color:${colors.textMuted};border-top:1px solid ${colors.border};">Valid until</td><td align="right" style="padding:12px 0;font-size:16px;font-weight:600;color:${colors.ink};border-top:1px solid ${colors.border};">${validUntil}</td></tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 32px 8px;">
                <p style="margin:0;font-size:16px;line-height:24px;">Show this code to the guard at the gate. They scan it when you arrive and when you leave.</p>
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:16px 32px 32px;">
                <a href="${url}" style="display:inline-block;padding:16px 32px;border-radius:999px;background:${colors.ink};color:${colors.brand};font-size:16px;font-weight:600;text-decoration:none;">Open my pass</a>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;

  const text = [
    `OMIS Entry — ${input.fullName}`,
    `${type} pass${input.plate ? `, vehicle ${input.plate}` : ""}`,
    `Valid until ${validUntil}`,
    "",
    "Show the QR code in this email to the guard at the gate.",
    `Open your pass: ${input.passUrl}`,
  ].join("\n");

  return { subject, html, text };
}
