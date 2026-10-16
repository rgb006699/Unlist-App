export type Method = "web_form" | "email" | "phone" | "mail" | "id_upload";
export type RelistRisk = "low" | "medium" | "high";
export type Status = "found" | "request_sent" | "removed" | "relisted";
export type ViewStatus = Status | "not_checked" | "due";

export interface Broker {
  id: string;
  name: string;
  searchUrl: string;
  optOutUrl: string;
  method: Method;
  optOutEmail: string | null;
  needsCaptcha: boolean;
  needsEmailConfirm: boolean;
  needsId: boolean;
  relistRisk: RelistRisk;
  steps: string[];
  lastVerified: string;
}

export interface Address {
  street: string;
  city: string;
  state: string;
  zip: string;
  current: boolean;
}

export interface Profile {
  fullName: string;
  aliases: string[];
  addresses: Address[];
  phones: string[];
  emails: string[];
}

export interface HistoryEntry {
  at: string;
  status: Status | "rechecked";
}

export interface BrokerRecord {
  status: Status;
  listingUrl: string;
  notes: string;
  requestSentAt: string | null;
  removedAt: string | null;
  recheckAt: string | null;
  history: HistoryEntry[];
}

export interface DataFile {
  version: 1;
  profile: Profile;
  settings: { recheckDays: number };
  records: Record<string, BrokerRecord>;
}

export interface RecordPatch {
  status?: Status;
  listingUrl?: string;
  notes?: string;
  recheck?: true;
}

export interface Progress {
  total: number;
  removed: number;
  pending: number;
  due: number;
  notChecked: number;
}
