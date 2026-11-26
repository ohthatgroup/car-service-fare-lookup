alter table public.shares
  add column if not exists public_fare jsonb
  check (
    public_fare is null
    or (
      jsonb_typeof(public_fare) = 'object'
      and octet_length(public_fare::text) <= 135000
      and public_fare ? 'amount'
      and jsonb_typeof(public_fare->'amount') = 'string'
    )
  );
