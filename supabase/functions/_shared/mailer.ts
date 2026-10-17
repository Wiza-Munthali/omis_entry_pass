// Sends one email. Production uses Resend (RESEND_API_KEY); local development posts
// to Mailpit's HTTP API (MAILPIT_URL) so every email shows up at http://127.0.0.1:54324.

export type InlineImage = { filename: string; contentId: string; base64: string; contentType: string };

export type Email = {
  to: string;
  subject: string;
  html: string;
  text: string;
  inline?: InlineImage[];
};

export async function sendEmail(email: Email): Promise<void> {
  const from = Deno.env.get("EMAIL_FROM") ?? "OMIS Entry <no-reply@ghii.test>";
  const resendKey = Deno.env.get("RESEND_API_KEY");
  const mailpitUrl = Deno.env.get("MAILPIT_URL");
  const inline = email.inline ?? [];

  let response: Response;
  if (resendKey) {
    response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from,
        to: [email.to],
        subject: email.subject,
        html: email.html,
        text: email.text,
        attachments: inline.map((i) => ({
          filename: i.filename,
          content: i.base64,
          content_type: i.contentType,
          content_id: i.contentId,
        })),
      }),
    });
  } else if (mailpitUrl) {
    const match = /^(?:(.*?)\s*<)?([^<>\s]+@[^<>\s]+)>?$/.exec(from);
    response = await fetch(`${mailpitUrl}/api/v1/send`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        From: { Email: match?.[2] ?? from, Name: match?.[1] ?? "" },
        To: [{ Email: email.to }],
        Subject: email.subject,
        HTML: email.html,
        Text: email.text,
        Attachments: inline.map((i) => ({
          Filename: i.filename,
          Content: i.base64,
          ContentType: i.contentType,
          ContentID: i.contentId,
        })),
      }),
    });
  } else {
    throw new Error("No email provider configured: set RESEND_API_KEY (or MAILPIT_URL for local development)");
  }

  if (!response.ok) {
    throw new Error(`Email provider returned ${response.status}: ${await response.text()}`);
  }
}
