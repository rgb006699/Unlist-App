import { mergeBrokers } from "./merge";
import { applyStatus, progress } from "./status";
import type { Broker, BrokerRecord } from "./types";

const T = "2026-10-15";

const mk = (id: string): Broker => ({
  id,
  name: id.toUpperCase(),
  searchUrl: `https://${id}.com`,
  optOutUrl: `https://${id}.com/optout`,
  method: "web_form",
  optOutEmail: null,
  needsCaptcha: false,
  needsEmailConfirm: false,
  needsId: false,
  relistRisk: "medium",
  steps: ["x"],
  lastVerified: T,
});

const brokers = ["a", "b", "c", "d", "e"].map(mk);

const records: Record<string, BrokerRecord> = {
  b: applyStatus(undefined, "found", T, 90),
  c: applyStatus(undefined, "request_sent", "2026-10-01", 90),
  d: applyStatus(undefined, "removed", "2026-10-01", 90), // recheck 2026-12-30
  e: applyStatus(undefined, "removed", "2026-06-01", 90), // recheck 2026-08-30 -> due
  orphan: applyStatus(undefined, "found", T, 90),
};

test("keeps broker order and marks missing records not_checked", () => {
  const rows = mergeBrokers(brokers, records, T);
  expect(rows.map((r) => r.broker.id)).toEqual(["a", "b", "c", "d", "e"]);
  expect(rows[0]).toEqual({ broker: brokers[0], record: null, view: "not_checked", nextDate: null });
});

test("nextDate follows the status", () => {
  const rows = mergeBrokers(brokers, records, T);
  expect(rows[1].nextDate).toBeNull();
  expect(rows[2].nextDate).toBe("2026-10-01");
  expect(rows[3].nextDate).toBe("2026-12-30");
  expect(rows[4].view).toBe("due");
  expect(rows[4].nextDate).toBe("2026-08-30");
});

test("orphan records produce no row and do not throw", () => {
  const rows = mergeBrokers(brokers, records, T);
  expect(rows.find((r) => r.broker.id === "orphan")).toBeUndefined();
  expect(rows).toHaveLength(5);
});

test("progress over merged rows", () => {
  const rows = mergeBrokers(brokers, records, T);
  expect(progress(rows.map((r) => r.view))).toEqual({ total: 5, removed: 1, pending: 2, due: 1, notChecked: 1 });
});
