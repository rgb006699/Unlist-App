import { mkdtemp, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import request from "supertest";
import { createApp } from "./app";
import { loadBrokers } from "./brokers";

const T = "2026-10-15";

const broker = (id: string, extra: object = {}) => ({
  id,
  name: id.toUpperCase(),
  searchUrl: `https://${id}.com`,
  optOutUrl: `https://${id}.com/optout`,
  method: "web_form",
  optOutEmail: null,
  needsCaptcha: false,
  needsEmailConfirm: false,
  needsId: false,
  relistRisk: "low",
  steps: ["Search"],
  lastVerified: T,
  ...extra,
});

let dir: string;
let brokersPath: string;
let app: ReturnType<typeof createApp>;

beforeEach(async () => {
  dir = await mkdtemp(join(tmpdir(), "unlist-app-"));
  brokersPath = join(dir, "brokers.json");
  await writeFile(brokersPath, JSON.stringify([broker("alpha"), broker("beta"), broker("gamma")]));
  app = createApp({ dataDir: join(dir, "data"), brokersPath, today: () => T });
});

const dataOnDisk = async () => JSON.parse(await readFile(join(dir, "data", "data.json"), "utf8"));

test("loadBrokers skips invalid and duplicate entries and logs them", async () => {
  await writeFile(brokersPath, JSON.stringify([broker("alpha"), broker("bad", { method: "fax" }), broker("alpha")]));
  const log: string[] = [];
  const list = loadBrokers(brokersPath, (m) => log.push(m));
  expect(list.map((b) => b.id)).toEqual(["alpha"]);
  expect(log).toHaveLength(2);
  expect(log[0]).toMatch(/^Skipping broker bad:/);
  expect(log[1]).toMatch(/^Skipping broker alpha: duplicate id/);
});

test("GET /api/brokers on a fresh install", async () => {
  const res = await request(app).get("/api/brokers");
  expect(res.status).toBe(200);
  expect(res.body.rows).toHaveLength(3);
  expect(res.body.rows.every((r: { view: string }) => r.view === "not_checked")).toBe(true);
  expect(res.body.progress).toEqual({ total: 3, removed: 0, pending: 0, due: 0, notChecked: 3 });
  expect(res.body.today).toBe(T);
  expect(res.body.recheckDays).toBe(90);
});

test("PATCH status removed sets recheck date and persists", async () => {
  const res = await request(app).patch("/api/brokers/alpha").send({ status: "removed" });
  expect(res.status).toBe(200);
  expect(res.body.view).toBe("removed");
  expect(res.body.nextDate).toBe("2027-01-13");
  expect((await dataOnDisk()).records.alpha.recheckAt).toBe("2027-01-13");
});

test("PATCH recheck restarts the clock", async () => {
  await request(app).patch("/api/brokers/alpha").send({ status: "removed" });
  const res = await request(app).patch("/api/brokers/alpha").send({ recheck: true });
  expect(res.body.record.history.at(-1)).toEqual({ at: T, status: "rechecked" });
});

test("PATCH recheck on a broker that is not removed is rejected", async () => {
  await request(app).patch("/api/brokers/alpha").send({ status: "found" });
  const res = await request(app).patch("/api/brokers/alpha").send({ recheck: true });
  expect(res.status).toBe(400);
  expect(res.body.code).toBe("INVALID");
});

test("PATCH listingUrl and notes on a not-checked broker creates a found record", async () => {
  const res = await request(app).patch("/api/brokers/beta").send({ notes: "hello", listingUrl: "https://beta.com/me" });
  expect(res.status).toBe(200);
  expect(res.body.record.notes).toBe("hello");
  expect(res.body.record.listingUrl).toBe("https://beta.com/me");
  expect(res.body.view).toBe("found");
});

test("PATCH validation errors", async () => {
  const bad = await request(app).patch("/api/brokers/alpha").send({ status: "bogus" });
  expect(bad.status).toBe(400);
  expect(bad.body.code).toBe("INVALID");
  const extra = await request(app).patch("/api/brokers/alpha").send({ status: "found", hack: 1 });
  expect(extra.status).toBe(400);
  const unknown = await request(app).patch("/api/brokers/nope").send({ status: "found" });
  expect(unknown.status).toBe(404);
  expect(unknown.body.code).toBe("UNKNOWN_BROKER");
});

test("PATCH the same status twice adds one history entry", async () => {
  await request(app).patch("/api/brokers/alpha").send({ status: "found" });
  const res = await request(app).patch("/api/brokers/alpha").send({ status: "found" });
  expect(res.body.record.history).toHaveLength(1);
});

test("PUT /api/profile round-trips and rejects bad bodies", async () => {
  const profile = { fullName: "Jane", aliases: [], addresses: [], phones: ["1"], emails: [] };
  const put = await request(app).put("/api/profile").send(profile);
  expect(put.status).toBe(200);
  expect(put.body).toEqual(profile);
  expect((await request(app).get("/api/profile")).body).toEqual(profile);
  const bad = await request(app).put("/api/profile").send({ fullName: 3 });
  expect(bad.status).toBe(400);
});

test("orphan records survive updates to other brokers", async () => {
  await request(app).patch("/api/brokers/alpha").send({ status: "found" });
  const data = await dataOnDisk();
  data.records.retired = data.records.alpha;
  await writeFile(join(dir, "data", "data.json"), JSON.stringify(data));
  await request(app).patch("/api/brokers/beta").send({ status: "found" });
  expect((await dataOnDisk()).records.retired).toBeDefined();
});

test("corrupt data returns 409 and restore recovers", async () => {
  await request(app).patch("/api/brokers/alpha").send({ status: "found" });
  await request(app).patch("/api/brokers/beta").send({ status: "found" });
  await writeFile(join(dir, "data", "data.json"), "{oops");
  const res = await request(app).get("/api/brokers");
  expect(res.status).toBe(409);
  expect(res.body.code).toBe("DATA_CORRUPT");
  const restore = await request(app).post("/api/data/restore").send({});
  expect(restore.status).toBe(200);
  expect(restore.body).toEqual({ ok: true });
  expect((await request(app).get("/api/brokers")).status).toBe(200);
});

test("restore with no backup returns 409", async () => {
  await request(app).get("/api/profile");
  await writeFile(join(dir, "data", "data.json"), "{oops");
  const res = await request(app).post("/api/data/restore").send({});
  expect(res.status).toBe(409);
});

test("requests from a foreign Host are refused", async () => {
  const res = await request(app).get("/api/profile").set("Host", "evil.example:3001");
  expect(res.status).toBe(403);
  expect(res.body.code).toBe("FORBIDDEN");
});

test("writes without a JSON content type are refused", async () => {
  const restore = await request(app).post("/api/data/restore").set("Content-Type", "text/plain").send("x");
  expect(restore.status).toBe(415);
  const patch = await request(app).patch("/api/brokers/alpha").set("Content-Type", "text/plain").send('{"status":"found"}');
  expect(patch.status).toBe(415);
});

test("localhost Host is accepted", async () => {
  const res = await request(app).get("/api/profile").set("Host", "localhost:5173");
  expect(res.status).toBe(200);
});
