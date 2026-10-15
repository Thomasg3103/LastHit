-- Last Hit leaderboard.
-- Run this once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.

create table if not exists public.scores (
  id         bigint generated always as identity primary key,
  name       text        not null check (char_length(btrim(name)) between 1 and 16),
  mode       text        not null check (mode in ('normal', 'one')),
  time_sec   integer     not null check (time_sec between 20 and 36000),
  pulls      integer     not null check (pulls between 0 and 10000),
  deaths     integer     not null check (deaths between 0 and 1000),
  peak       integer     not null check (peak between 0 and 100),
  created_at timestamptz not null default now(),
  -- a One life escape can't include a death
  constraint one_life_has_no_deaths check (mode <> 'one' or deaths = 0)
);

create index if not exists scores_board on public.scores (mode, time_sec, created_at);

-- Anyone with the game's public (anon) key can read the board and add a score,
-- but nobody can edit or delete scores from the browser.
alter table public.scores enable row level security;

drop policy if exists "read scores" on public.scores;
create policy "read scores" on public.scores
  for select to anon, authenticated using (true);

drop policy if exists "submit a score" on public.scores;
create policy "submit a score" on public.scores
  for insert to anon, authenticated with check (true);
