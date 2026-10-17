// Spec colour tokens for places CSS variables cannot reach (web manifest, theme-color).
// Everything else uses the CSS variables in app/globals.css. tests/design-tokens.test.ts
// keeps both in sync with docs/SPEC.md.
export const tokens = {
  brand: "#34C5A0",
  ink: "#111111",
  bg: "#EEEEEA",
} as const;
