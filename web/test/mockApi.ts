import { vi } from "vitest";

export type Route = { status?: number; body?: unknown } | ((init: RequestInit | undefined) => { status?: number; body?: unknown });

// Stubs global fetch with a table of "METHOD /path" -> response. Unknown
// routes fail the test loudly. Returns the mock to inspect calls.
export function mockApi(routes: Record<string, Route>) {
  const fn = vi.fn(async (url: string, init?: RequestInit) => {
    const key = `${init?.method ?? "GET"} ${url}`;
    const route = routes[key];
    if (!route) throw new Error(`Unmocked request: ${key}`);
    const { status = 200, body = {} } = typeof route === "function" ? route(init) : route;
    return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
  });
  vi.stubGlobal("fetch", fn);
  return fn;
}

export const calls = (fn: ReturnType<typeof mockApi>, key: string) =>
  fn.mock.calls.filter(([url, init]) => `${init?.method ?? "GET"} ${url}` === key);
