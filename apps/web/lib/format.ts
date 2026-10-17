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
