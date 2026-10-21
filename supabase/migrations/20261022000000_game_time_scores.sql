-- Leaderboard times match the in-game clock the player sees, instead of raw
-- wall-clock time (which also counted pauses, tab switches and the ending).
-- The server still bounds it: never more than the real time since the run
-- started, and never less than half of it, so a made-up time can't beat the
-- real one by much.

drop function if exists public.submit_score(uuid, integer, integer, integer);

create or replace function public.submit_score(p_run uuid, p_pulls integer, p_deaths integer, p_peak integer, p_time integer)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  r       public.runs%rowtype;
  elapsed integer;
  t       integer;
  sid     bigint;
begin
  select * into r from public.runs where id = p_run for update;
  if not found or r.user_id is distinct from auth.uid() then
    raise exception 'run not found';
  end if;
  if r.used_at is not null then
    raise exception 'run already submitted';
  end if;
  elapsed := floor(extract(epoch from now() - r.started_at))::integer;
  t := least(elapsed, greatest(coalesce(p_time, elapsed), floor(elapsed * 0.5)::integer));
  update public.runs set used_at = now() where id = p_run;
  insert into public.scores (user_id, mode, daily, time_sec, pulls, deaths, peak)
  values (r.user_id, r.mode, r.daily, t, p_pulls, p_deaths, p_peak)
  returning id into sid;
  return sid;
end;
$$;

revoke all on function public.submit_score(uuid, integer, integer, integer, integer) from public, anon;
grant execute on function public.submit_score(uuid, integer, integer, integer, integer) to authenticated;
