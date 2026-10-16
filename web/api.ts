import type { BrokerRow } from "../shared/merge";
import type { Profile, Progress, RecordPatch } from "../shared/types";

export class ApiError extends Error {
  constructor(
    public code: string,
    public status: number,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

export interface BrokersResponse {
  rows: BrokerRow[];
  progress: Progress;
  today: string;
  recheckDays: number;
}

async function request<T>(method: string, url: string, body?: unknown): Promise<T> {
  let res: Response;
  try {
    res = await fetch(url, {
      method,
      headers: body === undefined ? undefined : { "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new ApiError("UNREACHABLE", 0, "Can't reach Unlist server");
  }
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    // A proxy error page (server down behind Vite) has no JSON code.
    const code = typeof json.code === "string" ? json.code : res.status >= 500 ? "UNREACHABLE" : "UNKNOWN";
    throw new ApiError(code, res.status, json.message ?? `Request failed (${res.status})`);
  }
  return json as T;
}

export const api = {
  getProfile: () => request<Profile>("GET", "/api/profile"),
  saveProfile: (p: Profile) => request<Profile>("PUT", "/api/profile", p),
  getBrokers: () => request<BrokersResponse>("GET", "/api/brokers"),
  patchBroker: (id: string, patch: RecordPatch) =>
    request<BrokerRow>("PATCH", `/api/brokers/${encodeURIComponent(id)}`, patch),
  restore: () => request<{ ok: true }>("POST", "/api/data/restore"),
};
