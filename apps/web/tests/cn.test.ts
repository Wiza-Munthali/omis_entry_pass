import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { describe, expect, it } from "vitest";
import { cn } from "@/lib/utils";

describe("cn", () => {
  it("keeps a token colour alongside a spec type size", () => {
    expect(cn("text-brand", "text-body")).toBe("text-brand text-body");
    expect(cn("text-text-muted text-label")).toBe("text-text-muted text-label");
  });
  it("still lets a later size or colour win", () => {
    expect(cn("text-body", "text-title")).toBe("text-title");
    expect(cn("text-brand", "text-danger")).toBe("text-danger");
  });
  it("knows the card and sheet radii", () => {
    expect(cn("rounded-full", "rounded-card")).toBe("rounded-card");
  });
  it("is the only cn used in the app", () => {
    const root = join(__dirname, "..");
    const walk = (dir: string): string[] =>
      readdirSync(dir).flatMap((name) => {
        if (["node_modules", ".next", "public"].includes(name)) return [];
        const path = join(dir, name);
        return statSync(path).isDirectory()
          ? walk(path)
          : /\.tsx?$/.test(name)
            ? [path]
            : [];
      });
    const direct = walk(root)
      .filter((p) => !p.endsWith("lib/utils.ts"))
      .filter((p) =>
        /^import[^;]*from ["']cn["']/m.test(readFileSync(p, "utf8")),
      )
      .map((p) => relative(root, p));
    expect(direct).toEqual([]);
  });
});
