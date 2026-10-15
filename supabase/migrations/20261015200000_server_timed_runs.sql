-- The server keeps the clock. A run is started on the server when a signed-in player
-- wakes up, and the score's time is worked out from that start, not sent by the browser.

create table if not exists public.runs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  mode       text not null check (mode in ('normal', 'one')),
  started_at timestamptz not null default now(),
  used_at    timestamptz
);

create index if not exists runs_user on public.runs (user_id);

-- No policies: players can't read or write runs directly, only through the functions below.
alter table public.runs enable row level security;

create or replace function public.start_run(p_mode text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid;
begin
  if auth.uid() is null then
    raise exception 'sign in to start a timed run';
  end if;
  if p_mode not in ('normal', 'one') then
    raise exception 'unknown mode %', p_mode;
  end if;
  insert into public.runs (user_id, mode) values (auth.uid(), p_mode) returning id into rid;
  return rid;
end;
$$;

create or replace function public.submit_score(p_run uuid, p_pulls integer, p_deaths integer, p_peak integer)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  r   public.runs%rowtype;
  sid bigint;
begin
  select * into r from public.runs where id = p_run for update;
  if not found or r.user_id is distinct from auth.uid() then
    raise exception 'run not found';
  end if;
  if r.used_at is not null then
    raise exception 'run already submitted';
  end if;
  update public.runs set used_at = now() where id = p_run;
  insert into public.scores (user_id, mode, time_sec, pulls, deaths, peak)
  values (r.user_id, r.mode, floor(extract(epoch from now() - r.started_at))::integer, p_pulls, p_deaths, p_peak)
  returning id into sid;
  return sid;
end;
$$;

revoke all on function public.start_run(text) from public, anon;
grant execute on function public.start_run(text) to authenticated;
revoke all on function public.submit_score(uuid, integer, integer, integer) from public, anon;
grant execute on function public.submit_score(uuid, integer, integer, integer) to authenticated;

-- submit_score is now the only way a score gets in
drop policy if exists "submit your own score" on public.scores;
revoke insert, update, delete on public.scores from anon, authenticated;
