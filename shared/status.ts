import type { BrokerRecord, Progress, Status, ViewStatus } from "./types";

const pad = (n: number) => String(n).padStart(2, "0");

const format = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

// Local calendar date; toISOString() would give the UTC date.
export function todayISO(now: Date = new Date()): string {
  return format(now);
}

export function addDays(iso: string, days: number): string {
  const [y, m, d] = iso.split("-").map(Number);
  const date = new Date(y, m - 1, d);
  date.setDate(date.getDate() + days);
  return format(date);
}

function blankRecord(status: Status): BrokerRecord {
  return { status, listingUrl: "", notes: "", requestSentAt: null, removedAt: null, recheckAt: null, history: [] };
}

export function applyStatus(
  rec: BrokerRecord | undefined,
  status: Status,
  today: string,
  recheckDays: number,
): BrokerRecord {
  const base = rec ?? blankRecord(status);
  const next: BrokerRecord = { ...base, status, history: [...base.history, { at: today, status }] };
  if (status === "request_sent") next.requestSentAt = today;
  if (status === "removed") {
    next.removedAt = today;
    next.recheckAt = addDays(today, recheckDays);
  }
  if (status !== "removed") next.recheckAt = null;
  return next;
}

export function markStillRemoved(rec: BrokerRecord, today: string, recheckDays: number): BrokerRecord {
  return {
    ...rec,
    recheckAt: addDays(today, recheckDays),
    history: [...rec.history, { at: today, status: "rechecked" }],
  };
}

export function viewStatus(rec: BrokerRecord | undefined, today: string): ViewStatus {
  if (!rec) return "not_checked";
  if (rec.status === "removed" && rec.recheckAt !== null && rec.recheckAt <= today) return "due";
  return rec.status;
}

export function progress(statuses: ViewStatus[]): Progress {
  const count = (...s: ViewStatus[]) => statuses.filter((v) => s.includes(v)).length;
  return {
    total: statuses.length,
    removed: count("removed"),
    pending: count("found", "request_sent", "relisted"),
    due: count("due"),
    notChecked: count("not_checked"),
  };
}
