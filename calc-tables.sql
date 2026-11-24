-- Trip calculator tables + calculator share columns.
-- Run once in the Supabase SQL Editor (project axmamofelrnewhbtkwlu).
-- Do NOT run anything against the live database from a script; paste this
-- into the SQL Editor and run it there.
--
-- What this adds:
--   calc_configs — one row per signed-in driver: their rates + hubs.
--   calc_trips   — one row per saved trip (trip payload as jsonb).
--   shares.calc_fare / calc_route / calc_roundtrip — amount-only calculator
--     shares (/s/c<code>). The shared page shows the amount and the route
--     only, never rates or take-home.
--
-- Separate dashboard steps (not SQL, done once in the Supabase dashboard):
--   1. Authentication > Providers > Google: enable it with the Google
--      Cloud OAuth client ID + secret (free).
--   2. Authentication > URL Configuration: add the site URL
--      https://farelookup.vercel.app to Site URL and to Redirect URLs
--      (the app redirects back to /?view=settings after sign-in).

-- ---------- calculator config: one row per driver ----------
create table if not exists public.calc_configs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.calc_configs enable row level security;
drop policy if exists "calc_configs own" on public.calc_configs;
create policy "calc_configs own" on public.calc_configs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------- calculator trips: one row per saved trip ----------
create table if not exists public.calc_trips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trip_id text not null,
  trip jsonb not null,
  created_at timestamptz not null default now(),
  unique (user_id, trip_id)
);
alter table public.calc_trips enable row level security;
drop policy if exists "calc_trips own" on public.calc_trips;
create policy "calc_trips own" on public.calc_trips
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists calc_trips_user_created_idx
  on public.calc_trips (user_id, created_at);

-- ---------- calculator shares: amount-only (/s/c<code>) ----------
alter table public.shares
  add column if not exists calc_fare numeric,
  add column if not exists calc_route text,
  add column if not exists calc_roundtrip boolean not null default false;
