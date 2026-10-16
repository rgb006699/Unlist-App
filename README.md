# Unlist

A personal, local-only app for finding your listings on data broker / people-search
sites, sending removal requests, and getting reminded to recheck.

## Run it

```bash
npm install
npm run dev
```

Then open http://localhost:5173.

## Where your data lives

Your profile and progress are saved in `data/data.json` on this computer only
(with a `data/data.json.bak` backup). The `data/` folder is gitignored and is
never committed or sent anywhere. The broker list is `brokers.json`.

Unlist never sends email for you: it copies a request or opens a draft in your
mail app, and you press Send.

## Tests

```bash
npm test
```
