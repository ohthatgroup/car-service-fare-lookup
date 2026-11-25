-- Additive V2 ledger. No changes to legacy tables.
create table public.fl2_rentals (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 starts_on date not null, ends_before date not null, fixed_cost numeric(12,2) not null check(fixed_cost>=0),
 planned_hours numeric(10,3) not null check(planned_hours>0), hourly_goal numeric(10,2) not null check(hourly_goal>=0),
 created_at timestamptz not null default now(), unique(user_id,id), unique(user_id,starts_on), check(ends_before>starts_on)
);
create table public.fl2_jobs (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 rental_id uuid, business_date date not null, started_at timestamptz, ended_at timestamptz,
 pickup text, destination text, customer text, status text not null default 'quoted' check(status in ('quoted','scheduled','completed','cancelled')),
 fare numeric(12,2) check(fare>=0), working_minutes numeric(10,3) check(working_minutes>=0),
 rental_hourly_snapshot numeric(10,4) check(rental_hourly_snapshot>=0),
 review_state text not null default 'unverified' check(review_state in ('unverified','estimated','confirmed')),
 source text not null default 'manual', source_key text, notes text, created_at timestamptz not null default now(),
 unique(user_id,id), unique(user_id,source,source_key), foreign key(user_id,rental_id) references public.fl2_rentals(user_id,id),
 check(ended_at is null or (started_at is not null and ended_at>=started_at)),
 check(started_at is null or business_date=(started_at at time zone 'America/New_York')::date)
);
create table public.fl2_segments (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 job_id uuid, started_at timestamptz, ended_at timestamptz, business_date date not null,
 distance_mi numeric(12,3) check(distance_mi>=0), duration_minutes numeric(10,3) check(duration_minutes>=0),
 category text not null default 'unclassified' check(category in ('unclassified','pickup','passenger','waiting','empty_return','business_other','personal')),
 origin text, destination text, source text not null default 'manual', source_key text, created_at timestamptz not null default now(),
 unique(user_id,id), unique(user_id,source,source_key), foreign key(user_id,job_id) references public.fl2_jobs(user_id,id),
 check(ended_at is null or (started_at is not null and ended_at>=started_at)),
 check(started_at is null or business_date=(started_at at time zone 'America/New_York')::date)
);
create table public.fl2_expenses (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 job_id uuid, business_date date not null, category text not null check(category in ('toll','parking','other')),
 amount numeric(12,2) not null check(amount>=0), review_state text not null default 'unverified' check(review_state in ('unverified','estimated','confirmed')),
 source text not null default 'manual', source_key text, notes text, created_at timestamptz not null default now(),
 unique(user_id,id), unique(user_id,source,source_key), foreign key(user_id,job_id) references public.fl2_jobs(user_id,id)
);
create table public.fl2_fuel_purchases (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 purchased_at timestamptz, business_date date not null, amount numeric(12,2) not null check(amount>=0),
 gallons numeric(12,4) check(gallons>0), odometer_mi numeric(12,3) check(odometer_mi>=0),
 full_tank boolean, source text not null default 'manual', source_key text, notes text, created_at timestamptz not null default now(),
 unique(user_id,id), unique(user_id,source,source_key),
 check(purchased_at is null or business_date=(purchased_at at time zone 'America/New_York')::date)
);
create table public.fl2_fuel_allocations (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 purchase_id uuid not null, segment_id uuid not null, allocated_cost numeric(12,2) not null check(allocated_cost>=0),
 method text not null check(method in ('estimated','fill_to_fill','manual_confirmed')),
 created_at timestamptz not null default now(), unique(user_id,purchase_id,segment_id),
 foreign key(user_id,purchase_id) references public.fl2_fuel_purchases(user_id,id),
 foreign key(user_id,segment_id) references public.fl2_segments(user_id,id)
);
create table public.fl2_payments (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 job_id uuid not null, received_at timestamptz, received_on date not null,
 amount numeric(12,2) not null check(amount>0), method text, source text not null default 'manual', source_key text,
 created_at timestamptz not null default now(), unique(user_id,source,source_key),
 foreign key(user_id,job_id) references public.fl2_jobs(user_id,id)
);
create table public.fl2_reconciliations (
 user_id uuid not null references auth.users(id) on delete cascade, business_date date not null,
 state text not null default 'open' check(state in ('open','reviewed')),
 reviewed_at timestamptz, notes text, primary key(user_id,business_date),
 check(state<>'reviewed' or reviewed_at is not null)
);
do $$ declare t text; begin
 foreach t in array array['fl2_rentals','fl2_jobs','fl2_segments','fl2_expenses','fl2_fuel_purchases','fl2_fuel_allocations','fl2_payments','fl2_reconciliations'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon, public',t);
 execute format('grant select,insert,update,delete on public.%I to authenticated',t);
 execute format('create policy owner_only on public.%I for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id)',t);
 end loop;
end $$;
create index fl2_jobs_day_idx on public.fl2_jobs(user_id,business_date);
create index fl2_segments_day_idx on public.fl2_segments(user_id,business_date);
create index fl2_segments_job_idx on public.fl2_segments(user_id,job_id);
create index fl2_expenses_day_idx on public.fl2_expenses(user_id,business_date);
create index fl2_fuel_day_idx on public.fl2_fuel_purchases(user_id,business_date);
create index fl2_fuel_segment_idx on public.fl2_fuel_allocations(user_id,segment_id);
create index fl2_payments_job_idx on public.fl2_payments(user_id,job_id);
