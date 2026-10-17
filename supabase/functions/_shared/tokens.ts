// Design tokens for emails (HTML email cannot use CSS variables).
// Source of truth: docs/SPEC.md → "Design system". apps/web/tests/design-tokens.test.ts
// checks these values against the spec.
export const colors = {
  brand: "#34C5A0",
  brandStrong: "#1F9E7E",
  brandSoft: "#DDF5EF",
  ink: "#111111",
  text: "#1A1A1A",
  textMuted: "#6B6B6B",
  bg: "#EEEEEA",
  surface: "#FFFFFF",
  surface2: "#F5F5F2",
  border: "#E4E4E0",
} as const;
