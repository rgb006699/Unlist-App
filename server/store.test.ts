import { mkdtemp, readFile, writeFile, readdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createStore, DataCorruptError } from "./store";
import { emptyDataFile } from "../shared/schema";

let dir: string;
beforeEach(async () => {
  dir = await mkdtemp(join(tmpdir(), "unlist-store-"));
});

const read = async (name: string) => JSON.parse(await readFile(join(dir, name), "utf8"));

test("load creates an empty data file on first run", async () => {
  const store = createStore(join(dir, "nested"));
  expect(await store.load()).toEqual(emptyDataFile());
  expect(JSON.parse(await readFile(join(dir, "nested", "data.json"), "utf8"))).toEqual(emptyDataFile());
});

test("update writes, keeps a backup, and leaves no temp file", async () => {
  const store = createStore(dir);
  await store.update((d) => ({ ...d, profile: { ...d.profile, fullName: "First" } }));
  await store.update((d) => ({ ...d, profile: { ...d.profile, fullName: "Second" } }));
  expect((await read("data.json")).profile.fullName).toBe("Second");
  expect((await read("data.json.bak")).profile.fullName).toBe("First");
  expect(await readdir(dir)).not.toContain("data.json.tmp");
});

test("bad JSON throws DataCorruptError and leaves the file untouched", async () => {
  await writeFile(join(dir, "data.json"), "{not json");
  const store = createStore(dir);
  await expect(store.load()).rejects.toBeInstanceOf(DataCorruptError);
  await expect(store.update((d) => d)).rejects.toBeInstanceOf(DataCorruptError);
  expect(await readFile(join(dir, "data.json"), "utf8")).toBe("{not json");
});

test("valid JSON that fails the schema is corrupt", async () => {
  await writeFile(join(dir, "data.json"), JSON.stringify({ version: 2 }));
  await expect(createStore(dir).load()).rejects.toBeInstanceOf(DataCorruptError);
});

test("restore copies the backup over a corrupt file", async () => {
  const store = createStore(dir);
  await store.update((d) => ({ ...d, profile: { ...d.profile, fullName: "Saved" } }));
  await store.update((d) => d);
  await writeFile(join(dir, "data.json"), "garbage");
  const restored = await store.restore();
  expect(restored.profile.fullName).toBe("Saved");
  expect((await store.load()).profile.fullName).toBe("Saved");
});

test("restore without a backup throws", async () => {
  await writeFile(join(dir, "data.json"), "garbage");
  await expect(createStore(dir).restore()).rejects.toBeInstanceOf(DataCorruptError);
});

test("concurrent updates are serialized", async () => {
  const store = createStore(dir);
  await Promise.all([
    store.update((d) => ({ ...d, profile: { ...d.profile, aliases: [...d.profile.aliases, "one"] } })),
    store.update((d) => ({ ...d, profile: { ...d.profile, aliases: [...d.profile.aliases, "two"] } })),
  ]);
  expect((await store.load()).profile.aliases).toEqual(["one", "two"]);
});

test("a failed update does not block later ones", async () => {
  const store = createStore(dir);
  await expect(
    store.update(() => {
      throw new Error("boom");
    }),
  ).rejects.toThrow("boom");
  await store.update((d) => ({ ...d, profile: { ...d.profile, fullName: "After" } }));
  expect((await store.load()).profile.fullName).toBe("After");
});
