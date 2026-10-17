import { describe, expect, it } from "vitest";
import {
  QR_CONTENT_ID,
  renderPassEmail,
} from "../../../supabase/functions/_shared/pass-email.ts";

const input = {
  fullName: "Chikondi <b>Banda</b>",
  passType: "staff" as const,
  plate: "BT4521",
  validUntil: "2027-10-16T23:30:00Z",
  passUrl: "https://entry.example/pass",
};

describe("pass email", () => {
  const email = renderPassEmail(input);

  it("embeds the QR inline by content id", () => {
    expect(email.html).toContain(`src="cid:${QR_CONTENT_ID}"`);
  });
  it("escapes the holder's name", () => {
    expect(email.html).toContain("Chikondi &lt;b&gt;Banda&lt;/b&gt;");
    expect(email.html).not.toContain("<b>Banda</b>");
  });
  it("shows the pass type, plate, local expiry date and pass link", () => {
    expect(email.html).toContain("Staff");
    expect(email.html).toContain("BT4521");
    expect(email.html).toContain("17 Oct 2027");
    expect(email.html).toContain('href="https://entry.example/pass"');
  });
  it("has a plain-text fallback with the same facts", () => {
    expect(email.text).toContain("Valid until 17 Oct 2027");
    expect(email.text).toContain("https://entry.example/pass");
  });
  it("is 600 px wide", () => {
    expect(email.html).toContain('width="600"');
  });
});
