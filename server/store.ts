import { access, copyFile, mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { DataFileSchema, emptyDataFile } from "../shared/schema";
import type { DataFile } from "../shared/types";

export class DataCorruptError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DataCorruptError";
  }
}

const isMissing = (e: unknown) => (e as NodeJS.ErrnoException).code === "ENOENT";

const exists = (path: string) =>
  access(path).then(
    () => true,
    () => false,
  );

function parse(text: string, file: string): DataFile {
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    throw new DataCorruptError(`${file} is not valid JSON`);
  }
  const result = DataFileSchema.safeParse(json);
  if (!result.success) throw new DataCorruptError(`${file} does not match the expected format`);
  return result.data as DataFile;
}

export function createStore(dir: string) {
  const file = join(dir, "data.json");
  const bak = join(dir, "data.json.bak");
  const tmp = join(dir, "data.json.tmp");
  let queue: Promise<unknown> = Promise.resolve();

  // Runs fn after every earlier queued operation, whether or not they failed.
  function enqueue<T>(fn: () => Promise<T>): Promise<T> {
    const run = queue.then(fn, fn);
    queue = run.catch(() => {});
    return run;
  }

  async function write(data: DataFile): Promise<void> {
    await writeFile(tmp, JSON.stringify(data, null, 2) + "\n");
    try {
      await copyFile(file, bak);
    } catch (e) {
      if (!isMissing(e)) throw e;
    }
    await rename(tmp, file);
  }

  async function loadNow(): Promise<DataFile> {
    await mkdir(dir, { recursive: true });
    let text: string;
    try {
      text = await readFile(file, "utf8");
    } catch (e) {
      if (!isMissing(e)) throw e;
      // Seeding here would let the next save overwrite the only good backup.
      if (await exists(bak)) throw new DataCorruptError("data.json is missing but a backup exists");
      const fresh = emptyDataFile();
      await write(fresh);
      return fresh;
    }
    return parse(text, "data.json");
  }

  return {
    load: () => enqueue(loadNow),

    update: (fn: (d: DataFile) => DataFile) =>
      enqueue(async () => {
        const next = fn(await loadNow());
        await write(next);
        return next;
      }),

    restore: () =>
      enqueue(async () => {
        let text: string;
        try {
          text = await readFile(bak, "utf8");
        } catch (e) {
          if (isMissing(e)) throw new DataCorruptError("No backup file to restore from");
          throw e;
        }
        const data = parse(text, "data.json.bak");
        // Keep the unreadable file so hand edits are never lost.
        if (await exists(file)) await rename(file, join(dir, `data.json.corrupt-${Date.now()}`));
        await writeFile(tmp, text);
        await rename(tmp, file);
        return data;
      }),
  };
}

export type Store = ReturnType<typeof createStore>;
