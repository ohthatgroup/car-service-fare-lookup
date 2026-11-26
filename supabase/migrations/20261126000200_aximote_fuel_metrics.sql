alter table public.fl2_segments
  add column if not exists fuel_gallons numeric(12,4) check (fuel_gallons >= 0),
  add column if not exists fuel_rate_gal_per_100_mi numeric(12,4) check (fuel_rate_gal_per_100_mi >= 0),
  add column if not exists reported_fuel_cost numeric(12,2) check (reported_fuel_cost >= 0);
