import { z } from "zod";
import type { DataFile } from "./types";

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "must be YYYY-MM-DD");

export const StatusSchema = z.enum(["found", "request_sent", "removed", "relisted"]);

export const BrokerSchema = z
  .object({
    id: z.string().regex(/^[a-z0-9-]+$/, "must be a lowercase slug"),
    name: z.string().min(1),
    searchUrl: z.string().url(),
    optOutUrl: z.string().url(),
    method: z.enum(["web_form", "email", "phone", "mail", "id_upload"]),
    optOutEmail: z.string().email().nullable(),
    needsCaptcha: z.boolean(),
    needsEmailConfirm: z.boolean(),
    needsId: z.boolean(),
    relistRisk: z.enum(["low", "medium", "high"]),
    steps: z.array(z.string().min(1)),
    lastVerified: z.union([isoDate, z.literal("")]),
  })
  .refine((b) => b.method !== "email" || b.optOutEmail !== null, {
    message: "optOutEmail is required when method is email",
    path: ["optOutEmail"],
  });

export const AddressSchema = z.object({
  street: z.string(),
  city: z.string(),
  state: z.string(),
  zip: z.string(),
  current: z.boolean(),
});

export const ProfileSchema = z.object({
  fullName: z.string(),
  aliases: z.array(z.string()),
  addresses: z.array(AddressSchema),
  phones: z.array(z.string()),
  emails: z.array(z.string()),
});

export const BrokerRecordSchema = z.object({
  status: StatusSchema,
  listingUrl: z.string(),
  notes: z.string(),
  requestSentAt: isoDate.nullable(),
  removedAt: isoDate.nullable(),
  recheckAt: isoDate.nullable(),
  history: z.array(z.object({ at: isoDate, status: z.union([StatusSchema, z.literal("rechecked")]) })),
});

export const DataFileSchema = z.object({
  version: z.literal(1),
  profile: ProfileSchema,
  settings: z.object({ recheckDays: z.number().int().positive() }),
  records: z.record(BrokerRecordSchema),
});

export const RecordPatchSchema = z
  .object({
    status: StatusSchema.optional(),
    listingUrl: z.string().optional(),
    notes: z.string().optional(),
    recheck: z.literal(true).optional(),
  })
  .strict();

export function emptyDataFile(): DataFile {
  return {
    version: 1,
    profile: { fullName: "", aliases: [], addresses: [], phones: [], emails: [] },
    settings: { recheckDays: 90 },
    records: {},
  };
}
