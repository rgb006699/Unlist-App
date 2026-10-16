// @vitest-environment jsdom
import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { vi } from "vitest";
import { mergeBrokers } from "../../shared/merge";
import { applyStatus } from "../../shared/status";
import { fillTemplate, mailtoLink } from "../../shared/templates";
import type { Profile } from "../../shared/types";
import { calls, mockApi } from "../test/mockApi";
import { brokers, brokersResponse, records, TODAY } from "../test/fixtures";
import BrokerDetail from "./BrokerDetail";
import { STATUS_HELP } from "../labels";

const profile: Profile = {
  fullName: "Jane Doe",
  aliases: [],
  addresses: [{ street: "1 Main", city: "Austin", state: "TX", zip: "78701", current: true }],
  phones: [],
  emails: ["jane@example.com"],
};

afterEach(() => vi.unstubAllGlobals());

const renderDetail = (id: string) =>
  render(
    <MemoryRouter initialEntries={[`/broker/${id}`]}>
      <Routes>
        <Route path="/broker/:id" element={<BrokerDetail />} />
        <Route path="/" element={<p>dashboard</p>} />
      </Routes>
    </MemoryRouter>,
  );

const acxiom = brokers[2];
const echoPatch = (id: string) => (init: RequestInit | undefined) => {
  const body = JSON.parse(String(init?.body));
  const broker = brokers.find((b) => b.id === id)!;
  let rec = records[id];
  if (body.status) rec = applyStatus(rec, body.status, TODAY, 90);
  if (body.notes !== undefined || body.listingUrl !== undefined) {
    rec = rec ?? applyStatus(undefined, "found", TODAY, 90);
    rec = { ...rec, notes: body.notes ?? rec.notes, listingUrl: body.listingUrl ?? rec.listingUrl };
  }
  return { body: mergeBrokers([broker], { [id]: rec }, TODAY)[0] };
};

function setup(id = "acxiom") {
  const fetch = mockApi({
    "GET /api/brokers": { body: brokersResponse() },
    "GET /api/profile": { body: profile },
    [`PATCH /api/brokers/${id}`]: echoPatch(id),
  });
  renderDetail(id);
  return fetch;
}

test("shows steps and only the badges that apply", async () => {
  setup("spokeo");
  expect(await screen.findByRole("heading", { name: "Spokeo" })).toBeInTheDocument();
  const steps = within(screen.getByRole("list", { name: "Opt-out steps" })).getAllByRole("listitem");
  expect(steps.map((s) => s.textContent)).toEqual(["Search for your name", "Submit the form"]);
  expect(screen.getByText("CAPTCHA")).toBeInTheDocument();
  expect(screen.getByText("Email confirmation")).toBeInTheDocument();
  expect(screen.queryByText("ID required")).not.toBeInTheDocument();
});

test("links open the broker pages in a new tab", async () => {
  setup();
  const search = await screen.findByRole("link", { name: "Open search page" });
  expect(search).toHaveAttribute("href", acxiom.searchUrl);
  expect(search).toHaveAttribute("target", "_blank");
  expect(search).toHaveAttribute("rel", "noreferrer");
  expect(screen.getByRole("link", { name: "Open opt-out page" })).toHaveAttribute("href", acxiom.optOutUrl);
});

test("changing status saves it", async () => {
  const fetch = setup("spokeo");
  await userEvent.selectOptions(await screen.findByLabelText("Status"), "request_sent");
  const [, init] = calls(fetch, "PATCH /api/brokers/spokeo")[0];
  expect(JSON.parse(String(init?.body))).toEqual({ status: "request_sent" });
  const dates = await screen.findByRole("list", { name: "Dates" });
  expect(dates).toHaveTextContent("Request sentOct 15, 2026 · today");
  expect(screen.getByText(STATUS_HELP.request_sent)).toBeInTheDocument();
});

test("notes and listing URL save on blur", async () => {
  const fetch = setup();
  const notes = await screen.findByLabelText("Notes");
  await userEvent.type(notes, "called them");
  await userEvent.tab();
  const url = screen.getByLabelText("Listing URL");
  await userEvent.type(url, "https://acxiom.example/me");
  await userEvent.tab();
  const bodies = calls(fetch, "PATCH /api/brokers/acxiom").map(([, i]) => JSON.parse(String(i?.body)));
  expect(bodies).toEqual([{ notes: "called them" }, { listingUrl: "https://acxiom.example/me" }]);
});

test("blur without a change does not save", async () => {
  const fetch = setup();
  await userEvent.click(await screen.findByLabelText("Notes"));
  await userEvent.tab();
  expect(calls(fetch, "PATCH /api/brokers/acxiom")).toHaveLength(0);
});

test("history is newest first", async () => {
  setup();
  const items = within(await screen.findByRole("list", { name: "History" })).getAllByRole("listitem");
  expect(items.map((i) => i.textContent)).toEqual(["Oct 5, 2026Request sent", "Oct 1, 2026Found"]);
});

test("request panel previews, copies and opens mail", async () => {
  const writeText = vi.fn().mockResolvedValue(undefined);
  Object.defineProperty(navigator, "clipboard", { value: { writeText }, configurable: true });
  setup();
  const panel = await screen.findByRole("region", { name: "Removal request" });
  const tdpsa = fillTemplate("tdpsa", profile, acxiom, "");
  expect(await within(panel).findByText(/Texas Data Privacy and Security Act, I am exercising/)).toBeInTheDocument();

  await userEvent.click(within(panel).getByRole("button", { name: "General" }));
  const general = fillTemplate("general", profile, acxiom, "");
  expect(within(panel).queryByText(/Texas Data Privacy/)).not.toBeInTheDocument();

  await userEvent.click(within(panel).getByRole("button", { name: "Copy" }));
  expect(writeText).toHaveBeenCalledWith(`${general.subject}\n\n${general.body}`);
  expect(within(panel).getByRole("link", { name: "Open in Mail" })).toHaveAttribute(
    "href",
    mailtoLink(acxiom.optOutEmail, general.subject, general.body),
  );
  expect(tdpsa.subject).not.toBe(general.subject);
});

test("unknown broker", async () => {
  setup("nope");
  expect(await screen.findByText("Broker not found")).toBeInTheDocument();
  await userEvent.click(screen.getByRole("link", { name: "Back to dashboard" }));
  expect(screen.getByText("dashboard")).toBeInTheDocument();
});

test("a broker moved back from removed no longer shows a Removed date", async () => {
  const back = applyStatus(records.mylife, "found", TODAY, 90);
  mockApi({
    "GET /api/brokers": { body: brokersResponse({ ...records, mylife: back }) },
    "GET /api/profile": { body: profile },
  });
  renderDetail("mylife");
  await screen.findByRole("heading", { name: "MyLife" });
  const dates = screen.queryByRole("list", { name: "Dates" });
  expect(dates?.textContent ?? "").not.toMatch(/Removed|Recheck/);
});

test("a removed broker shows its removed and recheck dates", async () => {
  mockApi({ "GET /api/brokers": { body: brokersResponse() }, "GET /api/profile": { body: profile } });
  renderDetail("mylife");
  const dates = await screen.findByRole("list", { name: "Dates" });
  expect(dates).toHaveTextContent("RemovedOct 1, 2026 · 2 weeks ago");
  expect(dates).toHaveTextContent("RecheckDec 30, 2026 · in 3 months");
});
