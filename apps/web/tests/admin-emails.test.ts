import { describe, expect, it } from "vitest";
import {
  renderOperatorInviteEmail,
  renderRevokedEmail,
} from "../../../supabase/functions/_shared/pass-email.ts";

describe("admin emails", () => {
  it("revocation names the pass type and escapes the name", () => {
    const e = renderRevokedEmail({
      fullName: "Grace <Chirwa>",
      passType: "staff",
    });
    expect(e.subject).toContain("cancelled");
    expect(e.html).toContain("Grace &lt;Chirwa&gt;");
    expect(e.html).toContain("staff pass can no longer be used");
    expect(e.text).toContain("contact reception");
  });

  it("operator invite says the role and how to sign in", () => {
    const guard = renderOperatorInviteEmail({
      fullName: "Yamikani Phiri",
      role: "guard",
      orgName: "GHII",
    });
    expect(guard.html).toContain("as a guard");
    expect(guard.html).toContain("gate app");
    const admin = renderOperatorInviteEmail({ role: "admin", orgName: "GHII" });
    expect(admin.html).toContain("as an admin");
    expect(admin.html).toContain("admin dashboard");
  });
});
