-- Run once in Supabase Dashboard → SQL Editor.
-- No login: each browser generates a random sync key and reads/writes its row
-- only through the two functions below. The table itself is closed to anon,
-- so the public anon key can't list or overwrite other people's rows.
-- `data` holds the same JSON object the app keeps in localStorage under
-- `mortgage_profiles_v1` ({ [profileId]: profile }).

-- Table from the earlier email-login version; safe to drop if unused.
-- drop table if exists public.mortgage_profiles;

create table if not exists public.mortgage_store (
  sync_key   text primary key check (length(sync_key) >= 20),
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.mortgage_store enable row level security;
-- No policies on purpose: direct table access is denied; use the functions.
revoke all on public.mortgage_store from anon, authenticated;

create or replace function public.get_mortgage_store(p_key text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select data from public.mortgage_store where sync_key = p_key;
$$;

create or replace function public.set_mortgage_store(p_key text, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_key is null or length(p_key) < 20 then
    raise exception 'invalid sync key';
  end if;
  insert into public.mortgage_store (sync_key, data, updated_at)
  values (p_key, p_data, now())
  on conflict (sync_key) do update set data = excluded.data, updated_at = now();
end;
$$;

revoke all on function public.get_mortgage_store(text) from public;
revoke all on function public.set_mortgage_store(text, jsonb) from public;
grant execute on function public.get_mortgage_store(text) to anon, authenticated;
grant execute on function public.set_mortgage_store(text, jsonb) to anon, authenticated;
