# Car Service Fare Lookup

A public, community car-service price list. Pick where you're coming from and
where you're going — the top 4 bases (Borough Park, Monroe, Monsey, Lakewood)
are pinned, and every route works both ways — then pick your trip options and
get the price.

- **Add a price** for a route that isn't listed. It goes live right away.
- **Change a price** by suggesting a new one. The change needs **10 votes**
  from different people before it applies to everyone. Until then the current
  price stays in effect.

Seeded with 277 fares from printed price sheets dated May 22, 2023
(Borough Park, Monroe, Monsey, Lakewood + the Borough Park Flatbush zone grid).

## How it runs (all free tiers)

- **Hosting:** Netlify (static site, this repo)
- **Database:** Supabase (Postgres). The browser talks to it directly with the
  public anon key; row-level security in `supabase-setup.sql` decides what
  that key may do. Nobody can edit or delete a price directly — a price only
  changes inside the `cast_vote` database function when a proposal reaches
  10 votes, and each person (browser ID) gets one vote per proposal.

## Setup

1. Create a Supabase project, open its SQL Editor, and run
   `supabase-setup.sql` once (creates the tables, rules, vote function, and
   seeds the 277 fares).
2. Copy the project URL and anon key from Supabase (Settings → API) into
   `config.js`.
3. Deploy this folder/repo to Netlify (no build command; publish directory
   is the repo root, see `netlify.toml`).
