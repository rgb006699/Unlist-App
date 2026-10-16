# Unlist — Design Spec

Date: 2026-10-15
Source plan: "Data Removal Tracker – Build Plan" (Phases 1–5 in scope)

## Goal

Unlist is a personal, local-only app for one person (the owner) to track every
people-search / data broker site that lists them, generate removal requests,
and get reminded to recheck after a removal is confirmed.

Success: the owner opens Unlist, fills in their profile, works down a list of
~40 brokers using per-broker steps and ready-to-send requests, and the
dashboard shows progress and what is due for recheck.

## Decisions

| Topic | Decision |
| --- | --- |
| Users | One profile (the owner). No multi-profile support. |
| Storage | Local JSON file on disk, written by a small local server. |
| Legal template | Texas TDPSA deletion request + a general opt-out request. |
| Stack | React + Vite (TypeScript) UI, Express (TypeScript) API, Vitest, zod. |
| Sending | Never automatic. Copy to clipboard or open a `mailto:` draft. |

## Out of scope (for now)

- Calendar (.ics) export of recheck dates.
- Playwright automated scanning (Phase 6). The architecture leaves room for it
  as a server-side module, but nothing is built now.
- Multiple profiles, cloud sync, accounts, authentication.

## Architecture

```
brokers.json (seed list, committed)        data/data.json (owner's data, gitignored)
        │                                            │
        └──────► Express API (127.0.0.1:3001) ◄──────┘
                   GET  /api/profile
                   PUT  /api/profile
                   GET  /api/brokers          seed list merged with owner records
                   PATCH /api/brokers/:id     status, listingUrl, notes
                   POST /api/data/restore     restore data.json from data.json.bak
                        ▲
                        │ Vite dev proxy: /api → :3001
                 React + Vite UI (localhost:5173)
                   Dashboard · Broker detail · Profile
```

- One command, `npm run dev`, starts both the API and the Vite dev server.
- The API binds to `127.0.0.1` only.
- `brokers.json` (shared knowledge, refreshed every few months) and
  `data/data.json` (owner progress) are separate files so updating the broker
  list never touches progress.
- Writes are atomic: write `data.json.tmp`, copy the current file to
  `data.json.bak`, then rename the temp file over `data.json`.

### Units

| Unit | Responsibility | Depends on |
| --- | --- | --- |
| `shared/types.ts` | Broker, Profile, BrokerRecord, Status, DataFile types | — |
| `shared/schema.ts` | zod schemas for the above | zod |
| `shared/status.ts` | Status transitions, recheck date, "due" check, progress counts | types |
| `shared/templates.ts` | Fill TDPSA / general request text from profile + broker | types |
| `shared/merge.ts` | Merge seed brokers with owner records into view rows | types, status |
| `server/store.ts` | Load / atomic save / backup / restore of `data.json` | schema |
| `server/brokers.ts` | Load and validate `brokers.json`, skipping bad entries | schema |
| `server/app.ts` | Express routes | store, brokers, merge, status |
| `web/` | React screens and API client | shared, api |

`shared/` is pure TypeScript with no I/O, so the core logic is unit-testable
and used by both server and UI.

## Data model

### `brokers.json` (array)

```json
{
  "id": "spokeo",
  "name": "Spokeo",
  "searchUrl": "https://…",
  "optOutUrl": "https://…",
  "method": "web_form",
  "optOutEmail": null,
  "needsCaptcha": true,
  "needsEmailConfirm": true,
  "needsId": false,
  "relistRisk": "high",
  "steps": ["Search your name", "Copy your listing URL", "…"],
  "lastVerified": "2026-10-15"
}
```

- `id`: lowercase slug, unique.
- `method`: `web_form | email | phone | mail | id_upload`.
- `optOutEmail`: required when `method` is `email`, otherwise may be null.
- `relistRisk`: `low | medium | high`.
- Initial list: ~40 US people-search sites, generated with Claude Code and
  checked by hand; the Texas Secretary of State data broker registry is a
  source for additions. Opt-out URLs change, so `lastVerified` is recorded.

### `data/data.json`

```json
{
  "version": 1,
  "profile": {
    "fullName": "",
    "aliases": [],
    "addresses": [{ "street": "", "city": "", "state": "TX", "zip": "", "current": true }],
    "phones": [],
    "emails": []
  },
  "settings": { "recheckDays": 90 },
  "records": {
    "spokeo": {
      "status": "found",
      "listingUrl": "",
      "notes": "",
      "requestSentAt": null,
      "removedAt": null,
      "recheckAt": null,
      "history": [{ "at": "2026-10-15", "status": "found" }]
    }
  }
}
```

Dates are ISO `YYYY-MM-DD` strings in local time.

### Statuses and rules

Stored statuses: `found`, `request_sent`, `removed`, `relisted`.
`not_checked` is derived: a broker with no record.
`due` is derived: status `removed` and `recheckAt <= today`.

- Any status may be set from any status (the owner is in control); the rules
  below set dates as a side effect.
- → `request_sent`: `requestSentAt = today`.
- → `removed`: `removedAt = today`, `recheckAt = today + recheckDays`.
- Recheck of a due broker, "still removed": stays `removed`,
  `removedAt` unchanged, `recheckAt = today + recheckDays`, history entry added.
- → `relisted`: `recheckAt = null`.
- Every change appends `{ at, status }` to `history`.

Progress summary: counts of removed, pending (`found` + `request_sent` +
`relisted`), due, and not checked, out of the total broker count.

## Screens

1. **Dashboard**
   - Progress line, e.g. "28 of 40 removed · 5 pending · 3 need recheck".
   - "Due for recheck" panel at the top, shown only when something is due.
   - Broker table: name, method, status, next date (recheck or request sent).
     Filter by status and method; search by name. Row click opens detail.
2. **Broker detail**
   - Opt-out steps; buttons to open the search URL and opt-out URL in a new tab.
   - Requirement badges: CAPTCHA, email confirmation, ID.
   - Status picker, listing URL, notes, dates, history.
   - Request panel: template choice (Texas TDPSA / general), preview filled from
     the profile, **Copy** and **Open in Mail** (`mailto:` to `optOutEmail` when
     present, else empty recipient). The owner always sends it themselves.
3. **Profile**
   - Full name, aliases, addresses (one marked current), phones, emails.
   - Shown first when the profile is empty.

## Request templates

- **Texas TDPSA:** a consumer request to delete personal data under the Texas
  Data Privacy and Security Act, asking the broker to delete the listed
  personal data and confirm in writing. Includes name, aliases, current and
  past addresses, phones, emails, and the listing URL when known.
- **General:** a plain opt-out / removal request with the same identifying
  details and no legal citation.
- Fields left empty in the profile are omitted from the text, not shown blank.
- The template wording is a starting point, not legal advice; it lives in
  `shared/templates.ts` so the owner can edit it.

## Error handling

- Missing `data.json`: server creates an empty valid file on first run.
- Corrupt `data.json` (bad JSON or fails schema): server does not overwrite it,
  returns `409` with code `DATA_CORRUPT`; UI offers "Restore from backup",
  which calls `POST /api/data/restore`.
- Invalid write bodies: zod validation, `400` with a readable message; unknown
  broker id returns `404`.
- Server unreachable: UI shows a banner "Can't reach Unlist server — is
  `npm run dev` running?" and keeps unsaved form values on screen.
- Invalid `brokers.json` entries: skipped at load, id logged to the console.

## Testing

- Vitest throughout.
- `shared/`: test-first unit tests for status transitions and dates, due
  calculation, progress counts, template filling (including empty fields),
  and merge.
- `server/`: API tests (supertest) against a temporary data directory: read,
  write, atomic write + `.bak`, corrupt-file handling, restore, validation errors.
- `web/`: one smoke test per screen (Testing Library): renders, and changing a
  status calls the API.
- Manual (Phase 7): full flow on 3–5 real brokers.

## Privacy

- `data/` is gitignored. No telemetry, no external requests from the app other
  than links the owner clicks.
