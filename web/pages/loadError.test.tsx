// @vitest-environment jsdom
import { render, screen } from "@testing-library/react";
import type { ReactElement } from "react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { vi } from "vitest";
import BrokerDetail from "./BrokerDetail";
import Dashboard from "./Dashboard";
import Profile from "./Profile";

afterEach(() => vi.unstubAllGlobals());

const pages: [string, string, ReactElement][] = [
  ["Dashboard", "/", <Dashboard />],
  ["Profile", "/", <Profile />],
  ["BrokerDetail", "/broker/spokeo", <BrokerDetail />],
];

for (const [name, path, element] of pages) {
  test(`${name} shows a load error instead of Loading… when the request fails`, async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new TypeError("Failed to fetch")));
    render(
      <MemoryRouter initialEntries={[path]}>
        <Routes>
          <Route path="/" element={element} />
          <Route path="/broker/:id" element={element} />
        </Routes>
      </MemoryRouter>,
    );
    expect(await screen.findByText("Couldn't load this page.")).toBeInTheDocument();
    expect(screen.queryByText("Loading…")).not.toBeInTheDocument();
  });
}
