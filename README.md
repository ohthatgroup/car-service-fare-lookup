# Fare Lookup

**Live: [farelookup.vercel.app](https://farelookup.vercel.app)**

A public, community car-service price list. Pick where you're coming from and
where you're going — the top 4 bases are pinned, and every route works both
ways — then add your trip options and get the price.

Seeded with 263 place-to-place fares from printed price sheets dated
May 22, 2023 (Borough Park, Monroe, Monsey, Lakewood + the Borough Park
Flatbush zone grid). Only places are routes — the sheets' pricing rules
(mini-van addition brackets, the airport pickup fee, the zone grid) live in
the database as data and drive the app's logic.

Built free to use for the community by Shimmy Landau, who likes to solve
problems by building things — using LLMs and a bit of creativity.

## What it does

- **Quote wizard** — From → To → price, one step at a time. The price updates
  live as you toggle round trip, mini van, and airport pickup.
- **Price page, built around the driver loop** — get a rate, share it with
  the coordinator, get the next rate. A pinned bar at the bottom holds
  exactly two actions: **Share price** (primary) and **New rate**.
  Modifiers are plain rows, wait/extra are quiet text links, and suggesting
  a price change is a small muted link at the bottom — community maintenance,
  not part of the loop.
- **Extras** — under the price, **Add wait** (per hour or flat) and
  **Add extra** (custom charges like tolls) open drawers and roll into the
  total and the breakdown.
- **Share price** — shares a short link (e.g. `farelookup.vercel.app/s/83`)
  built for WhatsApp: the link preview image *is* the amount, options and
  extras included, and the link opens straight on the quote.
- **Add a price** — for a route that isn't listed, from the Board. It goes
  live right away for everyone.
- **Change a price** — suggest a new price from a small link under any quote. The proposal goes
  to the **Board**, where people vote ▲ Up or ▼ Down: a down vote cancels an
  up vote, tapping your vote again undoes it, and when a proposal's net
  score reaches **10**, the new price applies automatically. Until then the
  current price stays in effect.
- **The + button** — opens a drawer with the sheet notes, how voting works,
  a download link for the original May 2023 price-sheets PDF, and an About
  section with the open-source link above a link to message Shimmy.

## How it runs (all free tiers)

- **Hosting:** Vercel — static site plus two small functions in `api/`
  (`quote` builds the share landing page, `ogimg` draws the amount preview
  image). Netlify-format copies of the functions are kept in `netlify/` for
  parity; the old Netlify copy of the site is frozen and no longer canonical.
- **Database:** Supabase (Postgres). The browser talks to it directly with
  the public anon key; row-level security in `supabase-setup.sql` decides
  what that key may do. Nobody can edit or delete a price directly — a price
  only changes inside the `cast_vote` database function when a proposal
  reaches a net score of 10, and each person (browser ID) holds one vote
  per proposal.

## Setup

1. Create a Supabase project, open its SQL Editor, and run
   `supabase-setup.sql` once (creates the tables, rules, vote function, and
   seeds the 263 place fares).
2. Copy the project URL and anon key from Supabase (Settings → API) into
   `config.js`.
3. Deploy this repo to Vercel (no build command; `vercel.json` carries the
   `/s/…` and `/ogimg` rewrites). The original sheets PDF is served from a
   public Supabase Storage bucket (`site-files`).

## License

MIT — see `LICENSE`.
