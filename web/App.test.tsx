// @vitest-environment jsdom
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { vi } from "vitest";
import App from "./App";
import { calls, mockApi } from "./test/mockApi";

const profile = { fullName: "Jane", aliases: [], addresses: [], phones: [], emails: [] };
const brokers = { rows: [], progress: { total: 0, removed: 0, pending: 0, due: 0, notChecked: 0 }, today: "2026-10-15", recheckDays: 90 };

afterEach(() => vi.unstubAllGlobals());

const renderApp = (path = "/") =>
  render(
    <MemoryRouter initialEntries={[path]}>
      <App />
    </MemoryRouter>,
  );

test("shows a banner when the server can't be reached", async () => {
  vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new TypeError("Failed to fetch")));
  renderApp();
  expect(await screen.findByText(/Can't reach Unlist server/)).toBeInTheDocument();
});

test("offers restore when data is corrupt", async () => {
  let corrupt = true;
  const fetch = mockApi({
    "GET /api/profile": () => (corrupt ? { status: 409, body: { code: "DATA_CORRUPT", message: "bad" } } : { body: profile }),
    "GET /api/brokers": () => (corrupt ? { status: 409, body: { code: "DATA_CORRUPT", message: "bad" } } : { body: brokers }),
    "POST /api/data/restore": () => {
      corrupt = false;
      return { body: { ok: true } };
    },
  });
  renderApp();
  await userEvent.click(await screen.findByRole("button", { name: "Restore from backup" }));
  expect(calls(fetch, "POST /api/data/restore")).toHaveLength(1);
  expect(screen.queryByRole("button", { name: "Restore from backup" })).not.toBeInTheDocument();
});

test("sends a new user with an empty profile to the profile page", async () => {
  mockApi({
    "GET /api/profile": { body: { ...profile, fullName: "" } },
    "GET /api/brokers": { body: brokers },
  });
  renderApp();
  expect(await screen.findByRole("heading", { name: "Your details" })).toBeInTheDocument();
});

test("header shows the app name and navigation", async () => {
  mockApi({ "GET /api/profile": { body: profile }, "GET /api/brokers": { body: brokers } });
  renderApp();
  expect(screen.getByText("Unlist")).toBeInTheDocument();
  expect(screen.getByRole("link", { name: "Dashboard" })).toBeInTheDocument();
  expect(screen.getByRole("link", { name: "Profile" })).toBeInTheDocument();
});

test("the banner clears once a later request succeeds", async () => {
  let down = true;
  const ok = (body: unknown) => new Response(JSON.stringify(body), { status: 200, headers: { "Content-Type": "application/json" } });
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string) => {
      if (down) throw new TypeError("Failed to fetch");
      return ok(url === "/api/profile" ? profile : brokers);
    }),
  );
  renderApp();
  expect(await screen.findByText(/Can't reach Unlist server/)).toBeInTheDocument();
  down = false;
  await userEvent.click(screen.getByRole("link", { name: "Profile" }));
  await screen.findByRole("heading", { name: "Your details" });
  expect(screen.queryByText(/Can't reach Unlist server/)).not.toBeInTheDocument();
});

test("restore with nothing to restore just reloads and clears the banner", async () => {
  let corrupt = true;
  mockApi({
    "GET /api/profile": () => (corrupt ? { status: 409, body: { code: "DATA_CORRUPT", message: "bad" } } : { body: profile }),
    "GET /api/brokers": () => (corrupt ? { status: 409, body: { code: "DATA_CORRUPT", message: "bad" } } : { body: brokers }),
    "POST /api/data/restore": () => {
      corrupt = false; // fixed by hand in the meantime
      return { status: 409, body: { code: "NOTHING_TO_RESTORE", message: "nothing to restore" } };
    },
  });
  renderApp();
  await userEvent.click(await screen.findByRole("button", { name: "Restore from backup" }));
  await screen.findByText("Your removals");
  expect(screen.queryByRole("alert")).not.toBeInTheDocument();
});
