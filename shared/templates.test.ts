import { fillTemplate, mailtoLink } from "./templates";
import type { Broker, Profile } from "./types";

const broker: Broker = {
  id: "spokeo",
  name: "Spokeo",
  searchUrl: "https://www.spokeo.com",
  optOutUrl: "https://www.spokeo.com/optout",
  method: "email",
  optOutEmail: "privacy@spokeo.com",
  needsCaptcha: false,
  needsEmailConfirm: true,
  needsId: false,
  relistRisk: "high",
  steps: ["Search"],
  lastVerified: "2026-10-15",
};

const profile: Profile = {
  fullName: "Jane Q Doe",
  aliases: ["Jane Doe", "J. Smith"],
  addresses: [
    { street: "1 Old Rd", city: "Dallas", state: "TX", zip: "75201", current: false },
    { street: "22 New St", city: "Austin", state: "TX", zip: "78701", current: true },
  ],
  phones: ["512-555-0100"],
  emails: ["jane@example.com"],
};

const empty: Profile = { fullName: "", aliases: [], addresses: [], phones: [], emails: [] };

describe("tdpsa template", () => {
  const { subject, body } = fillTemplate("tdpsa", profile, broker, "https://www.spokeo.com/Jane-Doe/123");

  test("subject", () => {
    expect(subject).toBe("Request to delete my personal data — Texas Data Privacy and Security Act");
  });
  test("cites the Act and names the broker", () => {
    expect(body).toContain("Texas Data Privacy and Security Act");
    expect(body).toContain("Spokeo");
  });
  test("includes every identifying detail", () => {
    for (const s of ["Jane Q Doe", "Jane Doe", "J. Smith", "512-555-0100", "jane@example.com"]) {
      expect(body).toContain(s);
    }
    expect(body).toContain("22 New St, Austin, TX 78701");
    expect(body).toContain("1 Old Rd, Dallas, TX 75201");
  });
  test("lists the current address before previous ones", () => {
    const cur = body.indexOf("Current address");
    const prev = body.indexOf("Previous addresses");
    expect(cur).toBeGreaterThan(-1);
    expect(prev).toBeGreaterThan(cur);
    expect(body.indexOf("22 New St")).toBeLessThan(prev);
    expect(body.indexOf("1 Old Rd")).toBeGreaterThan(prev);
  });
  test("includes the listing URL", () => {
    expect(body).toContain("https://www.spokeo.com/Jane-Doe/123");
  });
});

describe("general template", () => {
  const { subject, body } = fillTemplate("general", profile, broker, "");
  test("subject", () => {
    expect(subject).toBe("Request to remove my personal information");
  });
  test("has no legal citation", () => {
    expect(body).not.toContain("Texas");
    expect(body).not.toContain("Act");
  });
  test("still has identifying details", () => {
    expect(body).toContain("Jane Q Doe");
    expect(body).toContain("512-555-0100");
  });
  test("omits the listing line when no URL is known", () => {
    expect(body).not.toMatch(/listing/i);
  });
});

describe("sparse profiles", () => {
  for (const id of ["tdpsa", "general"] as const) {
    test(`${id}: empty profile prints no blanks`, () => {
      const { body } = fillTemplate(id, empty, broker, "");
      expect(body).not.toContain("undefined");
      expect(body).not.toMatch(/\n\n\n/);
      expect(body).not.toMatch(/:\s*$/m);
    });
  }
  test("no current address puts all under one Addresses heading", () => {
    const p = { ...profile, addresses: profile.addresses.map((a) => ({ ...a, current: false })) };
    const { body } = fillTemplate("general", p, broker, "");
    expect(body).toContain("Addresses");
    expect(body).not.toContain("Current address");
    expect(body).not.toContain("Previous addresses");
    expect(body).toContain("22 New St, Austin, TX 78701");
  });
});

describe("mailtoLink", () => {
  test("encodes special characters so they round-trip", () => {
    const link = mailtoLink("privacy@x.com", "Hi & bye", "Line 1\nO'Brien #2");
    expect(link.startsWith("mailto:privacy@x.com?subject=")).toBe(true);
    const query = link.slice(link.indexOf("?") + 1);
    const parts = Object.fromEntries(query.split("&").map((kv) => kv.split("=").map(decodeURIComponent)));
    expect(parts.subject).toBe("Hi & bye");
    expect(parts.body).toBe("Line 1\nO'Brien #2");
  });
  test("no recipient", () => {
    expect(mailtoLink(null, "s", "b").startsWith("mailto:?subject=")).toBe(true);
  });
});
