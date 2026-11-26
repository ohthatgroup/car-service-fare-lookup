-- One owner-scoped transaction for linking or adopting a previously saved trip.
create function public.fl2_merge_saved_trip(
  p_trip_id text, p_job_id uuid, p_fare numeric, p_working_minutes numeric
) returns uuid
language plpgsql security invoker set search_path = ''
as $function$
declare
  owner_id uuid := auth.uid();
  payload jsonb;
  day date;
  target_id uuid;
begin
  select trip into strict payload from public.calc_trips
    where user_id = owner_id and trip_id = p_trip_id for update;

  select job_id into target_id from public.fl2_legacy_trip_links
    where user_id = owner_id and trip_id = p_trip_id;
  if target_id is not null then return target_id; end if;

  day := (payload->>'date')::date;
  if p_job_id is not null then
    select id into strict target_id from public.fl2_jobs
      where user_id = owner_id and id = p_job_id and business_date = day and status = 'completed';
  else
    if p_fare is null or p_fare < 0 or p_working_minutes < 0 then
      raise exception 'Enter the actual fare and any known working time';
    end if;
    insert into public.fl2_jobs (
      user_id, business_date, pickup, destination, status, fare, working_minutes, review_state, source, source_key
    ) values (
      owner_id, day, nullif(payload->>'from',''), nullif(payload->>'to',''), 'completed', p_fare,
      p_working_minutes, case when p_working_minutes is null then 'unverified' else 'confirmed' end,
      'legacy_calculator', p_trip_id
    ) returning id into target_id;
  end if;

  insert into public.fl2_legacy_trip_links(user_id, trip_id, job_id)
    values (owner_id, p_trip_id, target_id);
  return target_id;
end
$function$;
revoke all on function public.fl2_merge_saved_trip(text,uuid,numeric,numeric) from public, anon;
grant execute on function public.fl2_merge_saved_trip(text,uuid,numeric,numeric) to authenticated;
