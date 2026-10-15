-- Last Hit: player accounts and the leaderboard.

-- ---------- profiles: one per signed-up player, holds the public username ----------
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  username   text not null unique check (username ~ '^[A-Za-z0-9_.-]{3,16}$'),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles are public" on public.profiles;
create policy "profiles are public" on public.profiles
  for select to anon, authenticated using (true);

drop policy if exists "players can rename themselves" on public.profiles;
create policy "players can rename themselves" on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- create the profile from the username given at sign-up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'username', 'player_' || substr(new.id::text, 1, 6)));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- scores: every escape a signed-in player submits ----------
create table if not exists public.scores (
  id         bigint generated always as identity primary key,
  user_id    uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  mode       text not null check (mode in ('normal', 'one')),
  time_sec   integer not null check (time_sec between 20 and 36000),
  pulls      integer not null check (pulls between 0 and 10000),
  deaths     integer not null check (deaths between 0 and 1000),
  peak       integer not null check (peak between 0 and 100),
  created_at timestamptz not null default now(),
  -- a One life escape can't include a death
  constraint one_life_has_no_deaths check (mode <> 'one' or deaths = 0)
);

create index if not exists scores_board on public.scores (mode, time_sec, created_at);
create index if not exists scores_user on public.scores (user_id);

alter table public.scores enable row level security;

drop policy if exists "read scores" on public.scores;
create policy "read scores" on public.scores
  for select to anon, authenticated using (true);

-- you can only add scores as yourself; nobody can edit or delete scores from the game
drop policy if exists "submit your own score" on public.scores;
create policy "submit your own score" on public.scores
  for insert to authenticated with check (user_id = (select auth.uid()));

-- ---------- leaderboard: each player's best time per mode ----------
create or replace view public.leaderboard
with (security_invoker = true) as
select distinct on (s.mode, s.user_id)
  s.id, s.mode, s.user_id, p.username, s.time_sec, s.pulls, s.deaths, s.created_at
from public.scores s
join public.profiles p on p.id = s.user_id
order by s.mode, s.user_id, s.time_sec, s.created_at;

grant select on public.leaderboard to anon, authenticated;
