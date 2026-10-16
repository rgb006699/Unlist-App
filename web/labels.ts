import type { BrokerRow } from "../shared/merge";
import type { Method, ViewStatus } from "../shared/types";

export const STATUS_LABEL: Record<ViewStatus, string> = {
  not_checked: "Not checked",
  found: "Found",
  request_sent: "Request sent",
  removed: "Confirmed removed",
  relisted: "Re-listed",
  due: "Due for recheck",
};

export const METHOD_LABEL: Record<Method, string> = {
  web_form: "Web form",
  email: "Email",
  phone: "Phone",
  mail: "Mail",
  id_upload: "ID upload",
};

export function nextDateLabel(row: BrokerRow): string {
  if (!row.nextDate) return "—";
  return row.view === "request_sent" ? `Sent ${row.nextDate}` : `Recheck ${row.nextDate}`;
}
