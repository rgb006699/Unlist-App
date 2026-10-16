import type { BrokerRow } from "../shared/merge";
import type { Method, ViewStatus } from "../shared/types";
import { formatDate } from "./format";

export const STATUS_LABEL: Record<ViewStatus, string> = {
  not_checked: "Not checked",
  found: "Found",
  request_sent: "Request sent",
  removed: "Confirmed removed",
  relisted: "Re-listed",
  due: "Due for recheck",
};

// One plain sentence per status, shown under the status picker.
export const STATUS_HELP: Record<ViewStatus, string> = {
  not_checked: "You haven't searched this site for yourself yet.",
  found: "Your information is listed here. Next, ask them to remove it.",
  request_sent: "You've asked for removal. Waiting for the site to take your listing down.",
  removed: "Your listing is gone. Unlist will remind you to check again in case it comes back.",
  relisted: "Your listing came back. Send a new removal request.",
  due: "It's time to search again and make sure your listing hasn't come back.",
};

export const METHOD_LABEL: Record<Method, string> = {
  web_form: "Web form",
  email: "Email",
  phone: "Phone",
  mail: "Mail",
  id_upload: "ID upload",
};

// What the owner should do next for this broker, in a few words.
export function nextStep(row: BrokerRow): string {
  const rec = row.record;
  switch (row.view) {
    case "not_checked":
      return "Search for your listing";
    case "found":
      return "Send a removal request";
    case "request_sent":
      return rec?.requestSentAt ? `Waiting since ${formatDate(rec.requestSentAt)}` : "Waiting for removal";
    case "removed":
      return rec?.recheckAt ? `Recheck ${formatDate(rec.recheckAt)}` : "Removed";
    case "due":
      return "Search again now";
    case "relisted":
      return "Send a new request";
  }
}
