// @vitest-environment jsdom
import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { vi } from "vitest";
import type { Profile as ProfileT } from "../../shared/types";
import { calls, mockApi } from "../test/mockApi";
import Profile from "./Profile";

afterEach(() => vi.unstubAllGlobals());

const empty: ProfileT = { fullName: "", aliases: [], addresses: [], phones: [], emails: [] };

function setup(initial: ProfileT = empty, saveStatus = 200) {
  const fetch = mockApi({
    "GET /api/profile": { body: initial },
    "PUT /api/profile": (init) =>
      saveStatus === 200
        ? { body: JSON.parse(String(init?.body)) }
        : { status: saveStatus, body: { code: "INVALID", message: "fullName: bad" } },
  });
  render(
    <MemoryRouter>
      <Profile />
    </MemoryRouter>,
  );
  return fetch;
}

const savedBody = (fetch: ReturnType<typeof mockApi>) =>
  JSON.parse(String(calls(fetch, "PUT /api/profile").at(-1)![1]?.body));

test("saves trimmed values and drops empty rows", async () => {
  const fetch = setup();
  await userEvent.type(await screen.findByLabelText("Full name"), "  Jane Doe ");
  await userEvent.click(screen.getByRole("button", { name: "Add other name" }));
  await userEvent.type(screen.getByLabelText("Other name 1"), "J. Doe");
  await userEvent.click(screen.getByRole("button", { name: "Add other name" }));
  await userEvent.click(screen.getByRole("button", { name: "Add phone" }));
  await userEvent.type(screen.getByLabelText("Phone 1"), " 512-555-0100 ");
  await userEvent.click(screen.getByRole("button", { name: "Save" }));
  expect(savedBody(fetch)).toEqual({
    fullName: "Jane Doe",
    aliases: ["J. Doe"],
    addresses: [],
    phones: ["512-555-0100"],
    emails: [],
  });
  expect(await screen.findByText("Saved")).toBeInTheDocument();
});

test("rows can be removed", async () => {
  const fetch = setup({ ...empty, fullName: "Jane", emails: ["a@x.com", "b@x.com"] });
  await screen.findByDisplayValue("a@x.com");
  await userEvent.click(screen.getByRole("button", { name: "Remove email 1" }));
  await userEvent.click(screen.getByRole("button", { name: "Save" }));
  expect(savedBody(fetch).emails).toEqual(["b@x.com"]);
});

test("addresses default to TX and only one can be current", async () => {
  const fetch = setup({ ...empty, fullName: "Jane" });
  await screen.findByDisplayValue("Jane");
  await userEvent.click(screen.getByRole("button", { name: "Add address" }));
  await userEvent.click(screen.getByRole("button", { name: "Add address" }));
  const rows = screen.getAllByRole("group", { name: /^Address \d$/ });
  expect(within(rows[0]).getByLabelText("State")).toHaveValue("TX");
  await userEvent.type(within(rows[0]).getByLabelText("Street"), "1 Old Rd");
  await userEvent.type(within(rows[1]).getByLabelText("Street"), "2 New St");
  await userEvent.click(within(rows[1]).getByLabelText("Current"));
  await userEvent.click(within(rows[0]).getByLabelText("Current"));
  await userEvent.click(within(rows[1]).getByLabelText("Current"));
  await userEvent.click(screen.getByRole("button", { name: "Save" }));
  const saved = savedBody(fetch).addresses;
  expect(saved.map((a: { current: boolean }) => a.current)).toEqual([false, true]);
  expect(saved[0]).toEqual({ street: "1 Old Rd", city: "", state: "TX", zip: "", current: false });
});

test("address rows with nothing but a state are dropped", async () => {
  const fetch = setup({ ...empty, fullName: "Jane" });
  await screen.findByDisplayValue("Jane");
  await userEvent.click(screen.getByRole("button", { name: "Add address" }));
  await userEvent.click(screen.getByRole("button", { name: "Save" }));
  expect(savedBody(fetch).addresses).toEqual([]);
});

test("a failed save keeps what was typed and shows the error", async () => {
  setup(empty, 400);
  const name = await screen.findByLabelText("Full name");
  await userEvent.type(name, "Jane");
  await userEvent.click(screen.getByRole("button", { name: "Save" }));
  expect(await screen.findByText("fullName: bad")).toBeInTheDocument();
  expect(name).toHaveValue("Jane");
});
