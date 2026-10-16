# Unlist for iPhone — Faster Search Design Spec

Date: 2026-10-16
Builds on: `docs/superpowers/specs/2026-10-15-unlist-ios-design.md`

## Goal

Stop making the owner retype their details on every broker site. From a
broker page, one tap shows their search results; opt-out forms fill in with
one more tap; everything happens inside Unlist. The owner still reviews,
solves any CAPTCHA, and submits themselves.

Success: for the top brokers, the owner goes from "Not checked" to "Request
sent" without typing their name, address, phone or email anywhere.

## Decisions

| Topic | Decision |
| --- | --- |
| Platform | iPhone app only. The web app is unchanged. |
| Search | Optional `searchTemplate` per broker in `brokers.json`, filled from the profile. |
| Browser | In-app `WKWebView` sheet with a non-persistent (private) data store. |
| Autofill | "Fill my details" button: generic field matching plus optional per-broker selectors. Never submits. |
| Groups | Optional `group` per broker; shared opt-outs shown and updated together on request. |
| Privacy | Profile values are only ever typed into the page the owner is viewing. No new network calls by Unlist itself. |

## Out of scope

- Solving or bypassing CAPTCHAs, submitting forms, email/phone verification.
- Web app changes, multiple profiles, choosing a non-current address for search.
- Background or batch scanning of sites.

## Data: `brokers.json` additions

All new fields are optional; the web app ignores them.

```json
{
  "id": "truepeoplesearch",
  "searchTemplate": "https://www.truepeoplesearch.com/results?name={first}%20{last}&citystatezip={city},%20{state}",
  "group": "peopleconnect",
  "autofill": { "email": "#email", "firstName": "input[name=fn]" }
}
```

- `searchTemplate` — an `https://` URL with placeholders (below). Only added
  for brokers whose format was checked on the live site; others keep using
  `searchUrl`.
- `group` — a slug shared by brokers with one shared opt-out. Initially
  `peopleconnect` for Intelius, Instant Checkmate, TruthFinder, US Search,
  ZabaSearch.
- `autofill` — optional map from a profile field to a CSS selector, for
  sites where generic matching misses. Keys: `fullName`, `firstName`,
  `lastName`, `email`, `phone`, `street`, `city`, `state`, `zip`.

The broker-list loader validates the new fields: a template must start with
`https://` and use only known placeholders; `group` must be a slug; unknown
`autofill` keys are dropped. Invalid entries keep the broker but drop the bad
field (logged in debug builds).

## Search templates

Placeholders: `{first}`, `{last}`, `{middle}`, `{city}`, `{state}` (2-letter),
`{stateName}` (e.g. "Texas"), `{zip}`.

- `{token}` is percent-encoded for a URL query (RFC 3986 unreserved kept).
- `{token:slug}` is lowercased, accents removed, apostrophes dropped, and any
  run of other non-alphanumerics turned into `-`, for path-style URLs like
  `/name/jane-doe_austin-tx`.
- `{token:Slug}` is the same but keeps capitalization of each word
  (`Jane-Doe`, `Austin`), for sites like Spokeo.

Profile values:

- Name: `fullName` trimmed and split on whitespace. `first` = first word,
  `last` = last word, `middle` = the words between (may be empty). One-word
  names have no `last`.
- Address: the address marked current, else the first address.
- If a template needs a value that is empty, Unlist falls back to the plain
  `searchUrl` and shows "Add your city and state to search directly" (or
  the missing field) under the button.

## In-app browser

Opened from "Search page", "Opt-out page" and the due panel's "Search
again". A full-height sheet:

- Top bar: Done, page title/host, reload, Open in Safari (share sheet).
- `WKWebView` with `WKWebsiteDataStore.nonPersistent()`; JavaScript on;
  no access to Unlist data except through the fill action below.
- Bottom bar:
  - **Fill my details** (when the page has matching fields): runs the fill
    script; shows "Filled 4 fields — check them, then submit" or "No fields
    to fill on this page".
  - **My details**: a strip of copy chips — full name, each other name, each
    address (one line), each phone, each email. Tap copies and shows a check.
  - **Mark as…**: Found it / Request sent / Removed, which call the same
    model actions as the detail screen (group rule below applies).
- Links that open a new window load in the same view. `mailto:` and `tel:`
  hand off to the system.

## Autofill

A JavaScript function injected only when the owner taps Fill. It receives the
values as JSON and returns how many fields it filled.

1. Per-broker `autofill` selectors are tried first.
2. Generic matching for every visible, enabled, empty `input`/`select`/
   `textarea` (not `type=password|hidden|checkbox|radio|file`), using, in
   order: the `autocomplete` attribute (`given-name`, `family-name`, `name`,
   `email`, `tel`, `street-address`/`address-line1`, `address-level2`,
   `address-level1`, `postal-code`); then `name`, `id`, `placeholder`,
   `aria-label` and the associated `<label>` text matched against keyword
   lists (e.g. first: "first", "fname", "given"; last: "last", "lname",
   "surname", "family"; zip: "zip", "postal"; full name: "full name", "name"
   when no first/last field exists).
3. `select` fields for state are set to the option whose value or text
   matches the 2-letter code or full state name.
4. Each fill sets the value through the native setter and dispatches `input`
   and `change` events so React/Vue forms register it.
5. Fields that already have a value are left alone. Nothing is clicked or
   submitted.

The matching rules live in one JS file bundled with the app; the
value-mapping (which profile value goes to which key) is Swift and unit-tested.

## Groups

- Broker page shows "One opt-out covers N sites: …" for grouped brokers.
- Changing a grouped broker's status asks "Apply to all N sites in this
  group?" (Apply to all / Just this one). "Apply to all" sets the same status
  on each, following the normal status rules (history, recheck dates).
- Dashboard rows are unchanged.

## Error handling

- Page fails to load: the web view's error page with Reload; Open in Safari
  still available.
- Fill finds nothing: message above; copy chips still work.
- Profile empty: Fill and the chip bar show "Add your details in Profile
  first" with a button to the Profile tab.

## Testing

- Swift Testing:
  - Template filling: plain and `:slug`/`:Slug` forms; names with spaces,
    apostrophes (O'Brien), hyphens and accents (José); missing city →
    fallback; middle names; state name lookup.
  - Broker-list validation of the new fields.
  - Autofill value mapping from a profile (first/last/full name, current
    address, first phone/email).
  - Group status: apply to all updates every member with history; "just
    this one" changes one.
- JS fill script: tested in the simulator against a local test page with
  plain inputs, `autocomplete` attributes, label-only fields, a state
  `select`, and a React-style controlled input.
- By hand in the simulator: search links for every broker given a template
  open the owner's results; Fill on the top brokers' opt-out forms.
