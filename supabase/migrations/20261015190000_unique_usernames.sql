-- Usernames are the only thing players see: letters, numbers, _ and -,
-- and unique regardless of capitals ("Tom" and "tom" can't both exist).
alter table public.profiles drop constraint if exists profiles_username_check;
alter table public.profiles add constraint profiles_username_check check (username ~ '^[A-Za-z0-9_-]{3,16}$');

create unique index if not exists profiles_username_lower on public.profiles (lower(username));
