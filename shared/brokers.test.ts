import { readFileSync } from "node:fs";
import { BrokerSchema } from "./schema";

const list: unknown[] = JSON.parse(readFileSync(new URL("../brokers.json", import.meta.url), "utf8"));

test("every entry is a valid broker", () => {
  for (const entry of list) {
    const result = BrokerSchema.safeParse(entry);
    expect(result.success, JSON.stringify((entry as { id?: string }).id) + " " + JSON.stringify(result.error?.issues)).toBe(true);
  }
});

test("has at least 35 brokers with unique ids", () => {
  const ids = list.map((b) => (b as { id: string }).id);
  expect(ids.length).toBeGreaterThanOrEqual(35);
  expect(new Set(ids).size).toBe(ids.length);
});

test("all URLs are https and every entry has steps", () => {
  for (const b of list as { id: string; searchUrl: string; optOutUrl: string; steps: string[] }[]) {
    expect(b.searchUrl, b.id).toMatch(/^https:\/\//);
    expect(b.optOutUrl, b.id).toMatch(/^https:\/\//);
    expect(b.steps.length, b.id).toBeGreaterThan(0);
  }
});
