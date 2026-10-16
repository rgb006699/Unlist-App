// @vitest-environment jsdom
import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { vi } from "vitest";
import { mergeBrokers } from "../../shared/merge";
import { applyStatus, markStillRemoved } from "../../shared/status";
import { calls, mockApi } from "../test/mockApi";
import { brokers, brokersResponse, records, TODAY } from "../test/fixtures";
import Dashboard from "./Dashboard";

afterEach(() => vi.unstubAllGlobals());

const renderDashboard = () =>
  render(
    <MemoryRouter initialEntries={["/"]}>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/broker/:id" element={<p>detail page</p>} />
      </Routes>
    </MemoryRouter>,
  );

const bodyRows = () => within(screen.getByRole("table")).getAllByRole("row").slice(1);
const names = () => bodyRows().map((r) => within(r).getByRole("link").textContent);

test("shows the headline and a count per tile", async () => {
  mockApi({ "GET /api/brokers": { body: brokersResponse() } });
  renderDashboard();
  expect(await screen.findByText("1 of 5")).toBeInTheDocument();
  const tiles = within(screen.getByRole("group", { name: "Filter by progress" })).getAllByRole("button");
  expect(tiles.map((t) => t.textContent)).toEqual(["1Removed", "2In progress", "1Need recheck", "1Not checked yet"]);
});

test("tapping a tile filters the list, tapping again clears it", async () => {
  mockApi({ "GET /api/brokers": { body: brokersResponse() } });
  renderDashboard();
  await screen.findByRole("table");
  const tile = screen.getByRole("button", { name: /In progress/ });
  await userEvent.click(tile);
  expect(tile).toHaveAttribute("aria-pressed", "true");
  expect(names()).toEqual(["Whitepages", "Acxiom"]);
  await userEvent.click(tile);
  expect(names()).toHaveLength(5);
});

test("first-run guide shows only before anything is started", async () => {
  mockApi({ "GET /api/brokers": { body: brokersResponse({}) } });
  renderDashboard();
  expect(await screen.findByRole("heading", { name: "How Unlist works" })).toBeInTheDocument();
});

test("no first-run guide once work has started", async () => {
  mockApi({ "GET /api/brokers": { body: brokersResponse() } });
  renderDashboard();
  await screen.findByRole("table");
  expect(screen.queryByRole("heading", { name: "How Unlist works" })).not.toBeInTheDocument();
});

test("due panel: still removed and re-listed", async () => {
  const radarisRow = (rec: ReturnType<typeof applyStatus>) => mergeBrokers([brokers[4]], { radaris: rec }, TODAY)[0];
  const fetch = mockApi({
    "GET /api/brokers": { body: brokersResponse() },
    "PATCH /api/brokers/radaris": (init) => {
      const body = JSON.parse(String(init?.body));
      return {
        body: body.recheck
          ? radarisRow(markStillRemoved(records.radaris, TODAY, 90))
          : radarisRow(applyStatus(records.radaris, "relisted", TODAY, 90)),
      };
    },
  });
  renderDashboard();
  const panel = await screen.findByRole("region", { name: "Due for recheck" });
  expect(within(panel).getByText("Radaris")).toBeInTheDocument();

  await userEvent.click(within(panel).getByRole("button", { name: "Still removed" }));
  const [, init] = calls(fetch, "PATCH /api/brokers/radaris")[0];
  expect(JSON.parse(String(init?.body))).toEqual({ recheck: true });
  expect(screen.queryByRole("region", { name: "Due for recheck" })).not.toBeInTheDocument();
});

test("due panel: re-listed sends the status", async () => {
  const fetch = mockApi({
    "GET /api/brokers": { body: brokersResponse() },
    "PATCH /api/brokers/radaris": {
      body: mergeBrokers([brokers[4]], { radaris: applyStatus(records.radaris, "relisted", TODAY, 90) }, TODAY)[0],
    },
  });
  renderDashboard();
  const panel = await screen.findByRole("region", { name: "Due for recheck" });
  await userEvent.click(within(panel).getByRole("button", { name: "Re-listed" }));
  const [, init] = calls(fetch, "PATCH /api/brokers/radaris")[0];
  expect(JSON.parse(String(init?.body))).toEqual({ status: "relisted" });
});

test("no due panel when nothing is due", async () => {
  const { radaris: _, ...rest } = records;
  mockApi({ "GET /api/brokers": { body: brokersResponse(rest) } });
  renderDashboard();
  await screen.findByRole("table");
  expect(screen.queryByRole("region", { name: "Due for recheck" })).not.toBeInTheDocument();
});

test("filters by status, method and name", async () => {
  mockApi({ "GET /api/brokers": { body: brokersResponse() } });
  renderDashboard();
  await screen.findByRole("table");
  expect(bodyRows()).toHaveLength(5);

  await userEvent.selectOptions(screen.getByLabelText("Status"), "found");
  expect(names()).toEqual(["Whitepages"]);

  await userEvent.selectOptions(screen.getByLabelText("Status"), "");
  await userEvent.selectOptions(screen.getByLabelText("Method"), "email");
  expect(names()).toEqual(["Acxiom"]);

  await userEvent.selectOptions(screen.getByLabelText("Method"), "");
  await userEvent.type(screen.getByLabelText("Search"), "spo");
  expect(names()).toEqual(["Spokeo"]);
});

test("clicking a row opens the broker", async () => {
  mockApi({ "GET /api/brokers": { body: brokersResponse() } });
  renderDashboard();
  await screen.findByRole("table");
  await userEvent.click(within(bodyRows()[1]).getByText("Phone"));
  expect(screen.getByText("detail page")).toBeInTheDocument();
});

test("table shows broker, method, status and next step", async () => {
  mockApi({ "GET /api/brokers": { body: brokersResponse() } });
  renderDashboard();
  await screen.findByRole("table");
  const cells = (i: number) => within(bodyRows()[i]).getAllByRole("cell").map((c) => c.textContent);
  expect(cells(0)).toEqual(["SpokeoWeb form", "Not checked", "Search for your listing"]);
  expect(cells(2)).toEqual(["AcxiomEmail", "Request sent", "Waiting since Oct 5, 2026"]);
  expect(cells(3)).toEqual(["MyLifeID upload", "Confirmed removed", "Recheck Dec 30, 2026"]);
});
