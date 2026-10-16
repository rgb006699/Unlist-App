import { viewStatus } from "./status";
import type { Broker, BrokerRecord, ViewStatus } from "./types";

export interface BrokerRow {
  broker: Broker;
  record: BrokerRecord | null;
  view: ViewStatus;
  nextDate: string | null;
}

function nextDate(record: BrokerRecord | null): string | null {
  if (!record) return null;
  if (record.status === "removed") return record.recheckAt;
  if (record.status === "request_sent") return record.requestSentAt;
  return null;
}

// Records whose broker is no longer in the list are left alone, not shown.
export function mergeBrokers(brokers: Broker[], records: Record<string, BrokerRecord>, today: string): BrokerRow[] {
  return brokers.map((broker) => {
    const record = Object.hasOwn(records, broker.id) ? records[broker.id] : null;
    return { broker, record, view: viewStatus(record ?? undefined, today), nextDate: nextDate(record) };
  });
}
