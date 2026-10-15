-- Daily house: everyone gets the same seeded layout each (UTC) day, with its own board.
-- A run can be started as a daily run; its date is set by the server, not the browser.

alter table public.runs   add column if not exists daily date;
alter table public.scores add column if not exists daily date;

create index if not exists scores_daily on public.scores (daily, mode, time_sec);

drop function if exists public.start_run(text);
create or replace function public.start_run(p_mode text, p_daily boolean default false)
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
  insert into public.runs (user_id, mode, daily)
  values (auth.uid(), p_mode, case when p_daily then (now() at time zone 'utc')::date end)
  returning id into rid;
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
  insert into public.scores (user_id, mode, daily, time_sec, pulls, deaths, peak)
  values (r.user_id, r.mode, r.daily, floor(extract(epoch from now() - r.started_at))::integer, p_pulls, p_deaths, p_peak)
  returning id into sid;
  return sid;
end;
$$;

revoke all on function public.start_run(text, boolean) from public, anon;
grant execute on function public.start_run(text, boolean) to authenticated;
revoke all on function public.submit_score(uuid, integer, integer, integer) from public, anon;
grant execute on function public.submit_score(uuid, integer, integer, integer) to authenticated;

-- each player's best time per mode, and per day for daily runs
drop view if exists public.leaderboard;
create view public.leaderboard
with (security_invoker = true) as
select distinct on (s.mode, s.daily, s.user_id)
  s.id, s.mode, s.daily, s.user_id, p.username, s.time_sec, s.pulls, s.deaths, s.created_at
from public.scores s
join public.profiles p on p.id = s.user_id
order by s.mode, s.daily, s.user_id, s.time_sec, s.created_at;

grant select on public.leaderboard to anon, authenticated;
