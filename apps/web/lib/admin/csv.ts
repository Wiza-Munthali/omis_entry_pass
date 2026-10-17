/** One CSV field: quoted when needed; formula-leading values neutralised for spreadsheets. */
export function csvField(value: unknown): string {
  if (value === null || value === undefined) return "";
  let s = String(value);
  // A cell starting with = + - @ would run as a formula in Excel/Sheets.
  if (/^[=+\-@\t\r]/.test(s)) s = `'${s}`;
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

/** CSV text with a header row, CRLF line endings (what spreadsheets expect). */
export function toCsv(headers: string[], rows: unknown[][]): string {
  return (
    [headers, ...rows].map((r) => r.map(csvField).join(",")).join("\r\n") +
    "\r\n"
  );
}
