alter table public.fl2_jobs
  add column if not exists waiting_minutes numeric(10,3) check (waiting_minutes >= 0),
  add column if not exists driving_minutes numeric(10,3) check (driving_minutes >= 0),
  add column if not exists drive_ids uuid[];

alter table public.fl2_expenses
  add column if not exists job_ids uuid[] not null default '{}';

create or replace function public.fl2_save_actuals(
  p_job uuid, p_fare numeric, p_driving numeric, p_waiting numeric, p_drives uuid[],
  p_paid_on date, p_rate numeric, p_rental uuid, p_expected_status text
) returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  driver uuid := auth.uid();
  job public.fl2_jobs%rowtype;
begin
  select * into job from public.fl2_jobs
    where id = p_job and user_id = driver for update;
  if not found or job.status is distinct from p_expected_status
    or job.status not in ('quoted', 'scheduled', 'completed') then
    raise exception 'Refresh the job and try again.';
  end if;
  if p_fare is null or p_fare < 0 or p_driving is null or p_driving < 0
    or p_waiting is null or p_waiting < 0 or p_drives is null then
    raise exception 'Enter a valid fare and working time.';
  end if;
  if exists (
    select 1 from unnest(p_drives) as selected(id)
    where not exists (
      select 1 from public.fl2_segments as drive
      where drive.id = selected.id and drive.user_id = driver
        and drive.category <> 'personal' and drive.source in ('aximote', 'manual_car_trip')
    )
  ) then
    raise exception 'One or more selected drives are unavailable.';
  end if;

  update public.fl2_jobs set
    status = 'completed', fare = p_fare, driving_minutes = p_driving,
    waiting_minutes = p_waiting, working_minutes = p_driving + p_waiting,
    drive_ids = p_drives, review_state = 'confirmed',
    rental_hourly_snapshot = coalesce(job.rental_hourly_snapshot, p_rate),
    rental_id = coalesce(job.rental_id, p_rental)
    where id = p_job and user_id = driver;

  if p_paid_on is not null and p_fare > 0 and not exists (
    select 1 from public.fl2_payments where user_id = driver and job_id = p_job
  ) then
    insert into public.fl2_payments (user_id, job_id, received_on, amount, source, source_key)
      values (driver, p_job, p_paid_on, p_fare, 'job_actuals', p_job::text)
      on conflict (user_id, source, source_key) do nothing;
  end if;
end;
$$;

revoke execute on function public.fl2_save_actuals(uuid,numeric,numeric,numeric,uuid[],date,numeric,uuid,text) from public, anon;
grant execute on function public.fl2_save_actuals(uuid,numeric,numeric,numeric,uuid[],date,numeric,uuid,text) to authenticated;
