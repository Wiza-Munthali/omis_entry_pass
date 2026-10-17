// All times are stored in UTC and shown in Africa/Blantyre (CAT, UTC+2).
const dateFormat = new Intl.DateTimeFormat("en-GB", {
  day: "numeric",
  month: "short",
  year: "numeric",
  timeZone: "Africa/Blantyre",
});

/** "17 Oct 2027" */
export function formatDate(iso: string): string {
  return dateFormat.format(new Date(iso));
}

/** "bt4521" → "BT 4521" for display: letters, a space, then the rest. */
export function displayPlate(plate: string): string {
  const match = /^([A-Z]+)(\d.*)$/.exec(plate);
  return match ? `${match[1]} ${match[2]}` : plate;
}

/** "17 Oct 2026 at 10:42" in Africa/Blantyre. */
export function formatDateTime(iso: string): string {
  const d = new Date(iso);
  const time = new Intl.DateTimeFormat("en-GB", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
    timeZone: "Africa/Blantyre",
  }).format(d);
  return `${formatDate(iso)} at ${time}`;
}

/**
 * Visitor validity as days: "18 Oct 2026" for a day pass, "18 Oct – 24 Oct 2026" for a
 * week (valid_until is the following midnight, so the last day is the day before).
 */
export function formatValidity(
  passType: string,
  validFrom: string,
  validUntil: string,
): string {
  const first = formatDate(validFrom);
  const last = formatDate(
    new Date(new Date(validUntil).getTime() - 1).toISOString(),
  );
  if (passType === "day" || first === last) return first;
  const shortFirst = new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    timeZone: "Africa/Blantyre",
  }).format(new Date(validFrom));
  return `${shortFirst} – ${last}`;
}
