import { readFileSync } from "node:fs";
import { BrokerSchema } from "../shared/schema";
import type { Broker } from "../shared/types";

// Loads brokers.json, skipping (and logging) invalid or duplicate entries so
// one typo doesn't take down the whole list.
export function loadBrokers(path: string, log: (msg: string) => void = console.warn): Broker[] {
  const raw: unknown = JSON.parse(readFileSync(path, "utf8"));
  if (!Array.isArray(raw)) throw new Error(`${path} must contain a JSON array`);
  const seen = new Set<string>();
  const brokers: Broker[] = [];
  raw.forEach((entry, i) => {
    const label = typeof entry?.id === "string" ? entry.id : `#${i}`;
    const result = BrokerSchema.safeParse(entry);
    if (!result.success) {
      const issue = result.error.issues[0];
      log(`Skipping broker ${label}: ${issue.path.join(".")} ${issue.message}`);
      return;
    }
    if (seen.has(result.data.id)) {
      log(`Skipping broker ${label}: duplicate id`);
      return;
    }
    seen.add(result.data.id);
    brokers.push(result.data as Broker);
  });
  return brokers;
}
