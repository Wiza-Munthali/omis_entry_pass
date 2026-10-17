import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { describe, expect, it } from "vitest";

const webRoot = join(__dirname, "..");
const specPath = join(webRoot, "../../docs/SPEC.md");
const globalsPath = join(webRoot, "app/globals.css");

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
      .filter((path) => path !== globalsPath)
      .filter((path) => literal.test(readFileSync(path, "utf8")))
      .map((path) => relative(webRoot, path));
    expect(offenders).toEqual([]);
  });
});
