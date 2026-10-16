# Unlist

A personal, local-only app for finding your listings on data broker / people-search
sites, sending removal requests, and getting reminded to recheck.

## Run it

```bash
npm install
npm start
```

Then open http://localhost:3001. `npm start` builds the app and serves it from
the local Unlist server (only reachable from this computer).

For working on the code, `npm run dev` runs the Vite dev server with live
reload at http://localhost:5173.

## iPhone app

A native iPhone version lives in [`ios/`](ios/README.md). It stores everything
on the phone and adds recheck reminders as notifications.

## Where your data lives

Your profile and progress are saved in `data/data.json` on this computer only
(with a `data/data.json.bak` backup). The `data/` folder is gitignored and is
never committed or sent anywhere. The API only answers requests from this
computer.

If `data.json` can't be read, Unlist offers to restore `data.json.bak` (the
version before your last change) and keeps the unreadable file as
`data.json.corrupt-<time>`.

The broker list is `brokers.json`. Opt-out pages change often, so check each
one before relying on it. Restart Unlist after editing it.

Unlist never sends email for you: it copies a request or opens a draft in your
mail app, and you press Send.

## Tests

```bash
npm test
```
