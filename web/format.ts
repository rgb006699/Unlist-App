const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

const parts = (iso: string) => iso.split("-").map(Number) as [number, number, number];

// "2026-10-15" -> "Oct 15, 2026". Formatted by hand so it never shifts a day
// with the time zone.
export function formatDate(iso: string): string {
  const [y, m, d] = parts(iso);
  return `${MONTHS[m - 1]} ${d}, ${y}`;
}

const dayNumber = (iso: string) => {
  const [y, m, d] = parts(iso);
  return Date.UTC(y, m - 1, d) / 86_400_000;
};

const plural = (n: number, unit: string) => `${n} ${unit}${n === 1 ? "" : "s"}`;

// "in 3 months", "5 days ago", "today".
export function relativeDays(iso: string, today: string): string {
  const diff = dayNumber(iso) - dayNumber(today);
  const abs = Math.abs(diff);
  if (abs === 0) return "today";
  if (abs === 1) return diff > 0 ? "tomorrow" : "yesterday";
  const span =
    abs < 14
      ? plural(abs, "day")
      : abs < 60
        ? plural(Math.round(abs / 7), "week")
        : abs < 365
          ? plural(Math.round(abs / 30), "month")
          : plural(Math.round(abs / 365), "year");
  return diff > 0 ? `in ${span}` : `${span} ago`;
}
