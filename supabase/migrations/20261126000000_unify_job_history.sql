-- V2 keeps one job ledger. Link calculator evidence by its owner-scoped ID.
create table public.fl2_legacy_trip_links (
  user_id uuid not null references auth.users(id) on delete cascade,
  trip_id text not null,
  job_id uuid not null,
  primary key (user_id, trip_id),
  foreign key (user_id, trip_id) references public.calc_trips(user_id, trip_id) on delete cascade,
  foreign key (user_id, job_id) references public.fl2_jobs(user_id, id) on delete cascade
);

alter table public.fl2_legacy_trip_links enable row level security;
revoke all on public.fl2_legacy_trip_links from anon, public;
grant select, insert on public.fl2_legacy_trip_links to authenticated;
create policy owner_read on public.fl2_legacy_trip_links for select to authenticated
  using ((select auth.uid()) = user_id);
create policy owner_insert on public.fl2_legacy_trip_links for insert to authenticated
  with check ((select auth.uid()) = user_id);

alter table public.fl2_jobs add column return_pending boolean not null default false;
alter table public.fl2_payments alter column received_on drop not null;
