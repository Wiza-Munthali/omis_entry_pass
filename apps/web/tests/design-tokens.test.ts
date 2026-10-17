import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { describe, expect, it } from "vitest";

const webRoot = join(__dirname, "..");
const specPath = join(webRoot, "../../docs/SPEC.md");
const globalsPath = join(webRoot, "app/globals.css");
const tsTokensPath = join(webRoot, "lib/tokens.ts");
const repoRoot = join(webRoot, "../..");

/** Reads the Colors table in docs/SPEC.md → { token: "#rrggbb" }. */
function specColors(): Record<string, string> {
  const colors: Record<string, string> = {};
  const row =
    /^\|\s*`([a-z0-9-]+)`\s*\|\s*(#[0-9A-Fa-f]{6})(?:\s+on\s+(#[0-9A-Fa-f]{6}))?\s*\|/;
  for (const line of readFileSync(specPath, "utf8").split("\n")) {
    const m = row.exec(line);
    if (!m) continue;
    const [, name, fg, bg] = m;
    colors[name] = fg.toLowerCase();
    if (bg) colors[`${name}-soft`] = bg.toLowerCase();
  }
  return colors;
}

function cssVariables(css: string): Record<string, string> {
  const vars: Record<string, string> = {};
  for (const m of css.matchAll(/--([a-z0-9-]+):\s*(#[0-9a-fA-F]{6})\s*;/g)) {
    vars[m[1]] = m[2].toLowerCase();
  }
  return vars;
}

/** camelCase TS key → spec token name: brandStrong → brand-strong, surface2 → surface-2. */
function specName(key: string): string {
  return key
    .replace(/([A-Z])/g, "-$1")
    .replace(/(\d)/g, "-$1")
    .toLowerCase();
}

/** `key: "#RRGGBB"` pairs from a TS token module. */
function tsTokens(path: string): Record<string, string> {
  const out: Record<string, string> = {};
  for (const m of readFileSync(path, "utf8").matchAll(
    /(\w+):\s*"(#[0-9A-Fa-f]{6})"/g,
  )) {
    out[specName(m[1])] = m[2].toLowerCase();
  }
  return out;
}

function sourceFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    if (["node_modules", ".next", "public", "tests"].includes(name)) return [];
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return sourceFiles(path);
    return /\.(tsx?|css|mjs)$/.test(name) ? [path] : [];
  });
}

describe("design tokens", () => {
  const spec = specColors();

  it("finds the colour table in the spec", () => {
    expect(Object.keys(spec)).toEqual(
      expect.arrayContaining([
        "brand",
        "ink",
        "bg",
        "surface",
        "danger",
        "danger-soft",
      ]),
    );
  });

  it("globals.css defines every spec colour with the spec value", () => {
    const vars = cssVariables(readFileSync(globalsPath, "utf8"));
    for (const [name, hex] of Object.entries(spec)) {
      expect(vars[name], `--${name}`).toBe(hex);
    }
  });

  it("globals.css defines no colour that is not in the spec", () => {
    const vars = cssVariables(readFileSync(globalsPath, "utf8"));
    const extra = Object.keys(vars).filter((name) => !(name in spec));
    expect(extra).toEqual([]);
  });

  it("no other source file uses a literal colour", () => {
    const literal = /#[0-9a-fA-F]{3,8}\b|\b(?:rgba?|hsla?|oklch)\(/;
    const offenders = sourceFiles(webRoot)
      .filter((path) => path !== globalsPath && path !== tsTokensPath)
      .filter((path) => literal.test(readFileSync(path, "utf8")))
      .map((path) => relative(webRoot, path));
    expect(offenders).toEqual([]);
  });

  it.each([
    ["lib/tokens.ts", tsTokensPath],
    ["email tokens", join(repoRoot, "supabase/functions/_shared/tokens.ts")],
  ])("%s match the spec", (_label, path) => {
    const values = tsTokens(path);
    expect(Object.keys(values).length).toBeGreaterThan(0);
    for (const [name, hex] of Object.entries(values)) {
      expect(spec[name], name).toBe(hex);
    }
  });

  it("email HTML only uses spec colours", () => {
    const palette = new Set(Object.values(spec));
    const dir = join(repoRoot, "supabase/templates");
    const used = readdirSync(dir)
      .filter((f) => f.endsWith(".html"))
      .flatMap((f) =>
        [
          ...readFileSync(join(dir, f), "utf8").matchAll(/#[0-9A-Fa-f]{6}\b/g),
        ].map((m) => m[0].toLowerCase()),
      );
    expect(used.length).toBeGreaterThan(0);
    expect(used.filter((hex) => !palette.has(hex))).toEqual([]);
  });

  it("Edge Function code takes colours only from its tokens module", () => {
    const dir = join(repoRoot, "supabase/functions");
    const files = readdirSync(dir, { recursive: true, encoding: "utf8" })
      .filter((f) => f.endsWith(".ts") && !f.endsWith("_shared/tokens.ts"))
      .filter((f) =>
        /#[0-9A-Fa-f]{3,8}\b|\brgba?\(/.test(
          readFileSync(join(dir, f), "utf8"),
        ),
      );
    expect(files).toEqual([]);
  });
});
