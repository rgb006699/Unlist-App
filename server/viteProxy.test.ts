import config from "../vite.config";

// Vite proxies any path that starts with a proxy key, so "/api" would also
// swallow the source module "/api.ts" and leave the page blank.
test("dev proxy forwards API calls but not the web/api.ts module", () => {
  const keys = Object.keys(config.server?.proxy ?? {});
  expect(keys.length).toBeGreaterThan(0);
  for (const key of keys) {
    expect("/api.ts".startsWith(key), key).toBe(false);
    expect("/api/profile".startsWith(key), key).toBe(true);
  }
});
