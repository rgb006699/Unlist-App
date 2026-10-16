import { mergeBrokers } from "../../shared/merge";
import { applyStatus, progress } from "../../shared/status";
import type { Broker, BrokerRecord, Method } from "../../shared/types";

export const TODAY = "2026-10-15";

export const mkBroker = (id: string, name: string, method: Method = "web_form", extra: Partial<Broker> = {}): Broker => ({
  id,
  name,
  searchUrl: `https://${id}.example/search`,
  optOutUrl: `https://${id}.example/optout`,
  method,
  optOutEmail: method === "email" ? `privacy@${id}.example` : null,
  needsCaptcha: false,
  needsEmailConfirm: false,
  needsId: false,
  relistRisk: "medium",
  steps: ["Search for your name", "Submit the form"],
  lastVerified: TODAY,
  ...extra,
});

export const brokers: Broker[] = [
  mkBroker("spokeo", "Spokeo", "web_form", { needsCaptcha: true, needsEmailConfirm: true }),
  mkBroker("whitepages", "Whitepages", "phone"),
  mkBroker("acxiom", "Acxiom", "email"),
  mkBroker("mylife", "MyLife", "id_upload", { needsId: true }),
  mkBroker("radaris", "Radaris", "web_form"),
];

export const records: Record<string, BrokerRecord> = {
  whitepages: applyStatus(undefined, "found", "2026-10-10", 90),
  acxiom: applyStatus(applyStatus(undefined, "found", "2026-10-01", 90), "request_sent", "2026-10-05", 90),
  mylife: applyStatus(undefined, "removed", "2026-10-01", 90),
  radaris: applyStatus(undefined, "removed", "2026-06-01", 90), // due
};

export function brokersResponse(recs = records) {
  const rows = mergeBrokers(brokers, recs, TODAY);
  return { rows, progress: progress(rows.map((r) => r.view)), today: TODAY, recheckDays: 90 };
}
