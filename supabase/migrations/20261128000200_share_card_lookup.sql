alter table public.shares
  add column if not exists public_fare jsonb
  check (
    public_fare is null or (
      jsonb_typeof(public_fare) = 'object'
      and octet_length(public_fare::text) <= 135000
      and public_fare ? 'amount'
      and jsonb_typeof(public_fare->'amount') = 'string'
    )
  );

alter policy "shares read" on public.shares using (public_fare is null);

create or replace function public.fl_get_public_fare(p_code text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select share.public_fare
  from public.shares as share
  where p_code ~ '^[a-f0-9]{32}$' and share.code = p_code;
$$;

revoke execute on function public.fl_get_public_fare(text) from public;
grant execute on function public.fl_get_public_fare(text) to anon, authenticated;
