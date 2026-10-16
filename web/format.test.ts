import { formatDate, relativeDays } from "./format";
import { nextStep, STATUS_HELP } from "./labels";
import { mergeBrokers } from "../shared/merge";
import { applyStatus } from "../shared/status";
import { brokers, TODAY } from "./test/fixtures";

describe("formatDate", () => {
  test("short month, day, year", () => {
    expect(formatDate("2026-10-15")).toBe("Oct 15, 2026");
    expect(formatDate("2027-01-03")).toBe("Jan 3, 2027");
  });
});

describe("relativeDays", () => {
  test.each([
    ["2026-10-15", "today"],
    ["2026-10-16", "tomorrow"],
    ["2026-10-14", "yesterday"],
    ["2026-10-20", "in 5 days"],
    ["2026-10-10", "5 days ago"],
    ["2026-11-05", "in 3 weeks"],
    ["2027-01-13", "in 3 months"],
    ["2026-06-10", "4 months ago"],
    ["2028-01-01", "in 1 year"],
  ])("%s → %s", (iso, expected) => {
    expect(relativeDays(iso, TODAY)).toBe(expected);
  });
});

describe("nextStep", () => {
  const row = (rec: Parameters<typeof applyStatus>[0]) => mergeBrokers([brokers[0]], rec ? { spokeo: rec } : {}, TODAY)[0];

  test("tells the owner what to do for each status", () => {
    expect(nextStep(row(undefined))).toBe("Search for your listing");
    expect(nextStep(row(applyStatus(undefined, "found", TODAY, 90)))).toBe("Send a removal request");
    expect(nextStep(row(applyStatus(undefined, "request_sent", "2026-10-10", 90)))).toBe("Waiting since Oct 10, 2026");
    expect(nextStep(row(applyStatus(undefined, "removed", TODAY, 90)))).toBe("Recheck Jan 13, 2027");
    expect(nextStep(row(applyStatus(undefined, "relisted", TODAY, 90)))).toBe("Send a new request");
    expect(nextStep(row(applyStatus(undefined, "removed", "2026-06-01", 90)))).toBe("Search again now");
  });

  test("every status has a plain explanation", () => {
    for (const text of Object.values(STATUS_HELP)) expect(text.length).toBeGreaterThan(10);
  });
});
