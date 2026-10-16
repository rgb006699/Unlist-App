import { todayISO, addDays, applyStatus, markStillRemoved, viewStatus, progress } from "./status";
import { DataFileSchema, BrokerSchema, emptyDataFile } from "./schema";
import type { BrokerRecord } from "./types";

const T = "2026-10-15";

describe("dates", () => {
  test("todayISO uses the local date late at night", () => {
    expect(todayISO(new Date(2026, 9, 15, 23, 30))).toBe("2026-10-15");
  });
  test("todayISO pads month and day", () => {
    expect(todayISO(new Date(2026, 0, 5))).toBe("2026-01-05");
  });
  test("addDays crosses year and month ends", () => {
    expect(addDays("2026-10-15", 90)).toBe("2027-01-13");
    expect(addDays("2026-02-28", 1)).toBe("2026-03-01");
  });
});

describe("applyStatus", () => {
  test("creates a record from nothing", () => {
    expect(applyStatus(undefined, "found", T, 90)).toEqual({
      status: "found",
      listingUrl: "",
      notes: "",
      requestSentAt: null,
      removedAt: null,
      recheckAt: null,
      history: [{ at: T, status: "found" }],
    });
  });
  test("request_sent sets requestSentAt", () => {
    const rec = applyStatus(applyStatus(undefined, "found", "2026-10-01", 90), "request_sent", T, 90);
    expect(rec.requestSentAt).toBe(T);
  });
  test("removed sets removedAt and recheckAt", () => {
    const rec = applyStatus(undefined, "removed", T, 90);
    expect(rec.removedAt).toBe(T);
    expect(rec.recheckAt).toBe("2027-01-13");
  });
  test("relisted clears recheckAt and keeps removedAt", () => {
    const removed = applyStatus(undefined, "removed", T, 90);
    const rec = applyStatus(removed, "relisted", "2026-12-01", 90);
    expect(rec.recheckAt).toBeNull();
    expect(rec.removedAt).toBe(T);
  });
  test("appends one history entry and does not mutate input", () => {
    const a = applyStatus(undefined, "found", T, 90);
    const snapshot = structuredClone(a);
    const b = applyStatus(a, "request_sent", T, 90);
    expect(a).toEqual(snapshot);
    expect(b.history).toHaveLength(2);
    expect(b.history[1]).toEqual({ at: T, status: "request_sent" });
  });
});

describe("markStillRemoved", () => {
  test("restarts the recheck clock and logs rechecked", () => {
    const rec: BrokerRecord = applyStatus(undefined, "removed", T, 90);
    const next = markStillRemoved(rec, "2027-01-13", 90);
    expect(next.status).toBe("removed");
    expect(next.removedAt).toBe(T);
    expect(next.recheckAt).toBe("2027-04-13");
    expect(next.history.at(-1)).toEqual({ at: "2027-01-13", status: "rechecked" });
    expect(rec.history).toHaveLength(1);
  });
});

describe("viewStatus", () => {
  const removed = applyStatus(undefined, "removed", T, 90); // recheck 2027-01-13
  test("no record is not_checked", () => {
    expect(viewStatus(undefined, T)).toBe("not_checked");
  });
  test("removed is due on and after the recheck date", () => {
    expect(viewStatus(removed, "2027-01-13")).toBe("due");
    expect(viewStatus(removed, "2027-02-01")).toBe("due");
  });
  test("removed before the recheck date stays removed", () => {
    expect(viewStatus(removed, "2027-01-12")).toBe("removed");
  });
  test("other statuses pass through", () => {
    expect(viewStatus(applyStatus(undefined, "relisted", T, 90), T)).toBe("relisted");
  });
});

test("progress counts", () => {
  expect(progress(["removed", "due", "found", "request_sent", "relisted", "not_checked"])).toEqual({
    total: 6,
    removed: 1,
    pending: 3,
    due: 1,
    notChecked: 1,
  });
});

describe("schemas", () => {
  const broker = {
    id: "x",
    name: "X",
    searchUrl: "https://x.com",
    optOutUrl: "https://x.com/opt",
    method: "email",
    optOutEmail: null,
    needsCaptcha: false,
    needsEmailConfirm: false,
    needsId: false,
    relistRisk: "low",
    steps: ["a"],
    lastVerified: "2026-10-15",
  };
  test("empty data file is valid", () => {
    expect(() => DataFileSchema.parse(emptyDataFile())).not.toThrow();
  });
  test("email method requires optOutEmail", () => {
    expect(BrokerSchema.safeParse(broker).success).toBe(false);
    expect(BrokerSchema.safeParse({ ...broker, optOutEmail: "p@x.com" }).success).toBe(true);
  });
  test("lastVerified may be empty but not free text", () => {
    expect(BrokerSchema.safeParse({ ...broker, optOutEmail: "p@x.com", lastVerified: "" }).success).toBe(true);
    expect(BrokerSchema.safeParse({ ...broker, optOutEmail: "p@x.com", lastVerified: "soon" }).success).toBe(false);
  });
});
