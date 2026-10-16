import express, { type NextFunction, type Request, type Response } from "express";
import { ZodError } from "zod";
import { mergeBrokers } from "../shared/merge";
import { ProfileSchema, RecordPatchSchema } from "../shared/schema";
import { applyStatus, markStillRemoved, progress, todayISO } from "../shared/status";
import type { BrokerRecord, Profile } from "../shared/types";
import { loadBrokers } from "./brokers";
import { createStore, DataCorruptError } from "./store";

class HttpError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
  ) {
    super(message);
  }
}

type Handler = (req: Request, res: Response) => Promise<void>;
const route = (fn: Handler) => (req: Request, res: Response, next: NextFunction) => fn(req, res).catch(next);

export function createApp(opts: { dataDir: string; brokersPath: string; today?: () => string }) {
  const today = opts.today ?? (() => todayISO());
  const store = createStore(opts.dataDir);
  const brokers = loadBrokers(opts.brokersPath);
  const app = express();
  app.use(express.json());

  app.get(
    "/api/profile",
    route(async (_req, res) => {
      res.json((await store.load()).profile);
    }),
  );

  app.put(
    "/api/profile",
    route(async (req, res) => {
      const profile = ProfileSchema.parse(req.body) as Profile;
      await store.update((d) => ({ ...d, profile }));
      res.json(profile);
    }),
  );

  app.get(
    "/api/brokers",
    route(async (_req, res) => {
      const data = await store.load();
      const t = today();
      const rows = mergeBrokers(brokers, data.records, t);
      res.json({ rows, progress: progress(rows.map((r) => r.view)), today: t, recheckDays: data.settings.recheckDays });
    }),
  );

  app.patch(
    "/api/brokers/:id",
    route(async (req, res) => {
      const broker = brokers.find((b) => b.id === req.params.id);
      if (!broker) throw new HttpError(404, "UNKNOWN_BROKER", `Unknown broker: ${req.params.id}`);
      const patch = RecordPatchSchema.parse(req.body);
      const t = today();
      const data = await store.update((d) => {
        const days = d.settings.recheckDays;
        let rec: BrokerRecord | undefined = d.records[broker.id];
        if (patch.status && patch.status !== rec?.status) rec = applyStatus(rec, patch.status, t, days);
        if (patch.recheck) {
          if (rec?.status !== "removed") throw new HttpError(400, "INVALID", "Only removed brokers can be rechecked");
          rec = markStillRemoved(rec, t, days);
        }
        if (patch.listingUrl !== undefined || patch.notes !== undefined) {
          rec = rec ?? applyStatus(undefined, "found", t, days);
          rec = { ...rec, listingUrl: patch.listingUrl ?? rec.listingUrl, notes: patch.notes ?? rec.notes };
        }
        return rec ? { ...d, records: { ...d.records, [broker.id]: rec } } : d;
      });
      res.json(mergeBrokers([broker], data.records, t)[0]);
    }),
  );

  app.post(
    "/api/data/restore",
    route(async (_req, res) => {
      await store.restore();
      res.json({ ok: true });
    }),
  );

  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (err instanceof HttpError) {
      res.status(err.status).json({ code: err.code, message: err.message });
    } else if (err instanceof ZodError) {
      const issue = err.issues[0];
      res.status(400).json({ code: "INVALID", message: `${issue.path.join(".") || "body"}: ${issue.message}` });
    } else if (err instanceof DataCorruptError) {
      res.status(409).json({ code: "DATA_CORRUPT", message: err.message });
    } else {
      console.error(err);
      res.status(500).json({ code: "SERVER_ERROR", message: "Something went wrong on the Unlist server" });
    }
  });

  return app;
}
