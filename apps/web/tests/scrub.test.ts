import { describe, expect, it } from "vitest";
import {
  scrubBreadcrumb,
  scrubEvent,
  scrubText,
  scrubUrl,
} from "@/lib/observability/scrub";

const STATUS_TOKEN = "Zq3vX9k2LmN8pR4tY6wB1cD5fG7hJ0aS"; // 32 chars, like a real one

describe("scrubText", () => {
  it("masks emails, phone numbers and tokens", () => {
    expect(
      scrubText(
        `duplicate key (email)=(grace@gmail.com) phone +265 991 234 567 token ${STATUS_TOKEN}`,
      ),
    ).toBe("duplicate key (email)=([email]) phone [phone] token [token]");
  });

  it("keeps dates, times and short numbers", () => {
    expect(scrubText("pass expired 2026-10-17 at 23:59, 30 days")).toBe(
      "pass expired 2026-10-17 at 23:59, 30 days",
    );
  });
});

describe("scrubUrl", () => {
  it("drops the query and masks token segments", () => {
    expect(
      scrubUrl(`https://entry.ghii.org/r/${STATUS_TOKEN}?from=email#qr`),
    ).toBe("https://entry.ghii.org/r/[token]");
    expect(scrubUrl("/admin/visits?q=Grace%20Chirwa")).toBe("/admin/visits");
  });
});

describe("scrubEvent", () => {
  it("removes request data and identity, keeps the user id", () => {
    const out = scrubEvent({
      request: {
        url: `https://entry.ghii.org/r/${STATUS_TOKEN}`,
        cookies: { "sb-access-token": "x" },
        headers: { authorization: "Bearer x" },
        data: { full_name: "Grace Chirwa" },
        query_string: "q=Grace",
      },
      user: { id: "u1", email: "grace@ghii.org", ip_address: "10.0.0.1" },
      exception: {
        values: [{ value: "Could not email grace@ghii.org" }, {}],
      },
      breadcrumbs: [
        { category: "console", message: "form grace@ghii.org" },
        {
          category: "fetch",
          data: { url: "/rest/v1/rpc/search_visits?q=Grace", body: "{}" },
        },
      ],
    });
    expect(out.request).toEqual({ url: "https://entry.ghii.org/r/[token]" });
    expect(out.user).toEqual({ id: "u1" });
    expect(out.exception?.values?.[0].value).toBe("Could not email [email]");
    expect(out.breadcrumbs).toEqual([
      { category: "fetch", data: { url: "/rest/v1/rpc/search_visits" } },
    ]);
  });

  it("drops console breadcrumbs on their own", () => {
    expect(scrubBreadcrumb({ category: "console", message: "hi" })).toBeNull();
  });
});
