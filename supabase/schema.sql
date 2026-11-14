-- Dyna-Mites online play. Paste into the Supabase SQL editor and run once.
-- Every player is an anonymous Supabase user (no email). auth.uid() is their guest ID.

-- ---------- matches ----------
create table if not exists public.games (
  code       text primary key check (code ~ '^[A-Z2-9]{6}$'),   -- the invite code in the link
  p0         uuid not null default auth.uid(),                 -- player 1 (Ember), the creator
  p1         uuid,                                              -- player 2 (Frost), set on join
  status     text not null default 'open' check (status in ('open', 'active', 'over')),
  turn       integer not null default 0,
  data       jsonb not null,                                    -- battlefield + last turn's replay
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.games enable row level security;

-- anyone with the invite code can read the match (needed to join or watch)
drop policy if exists "read matches" on public.games;
create policy "read matches" on public.games for select to authenticated using (true);

-- you can only create a match with yourself as player 1 and nobody else in it
drop policy if exists "create own match" on public.games;
create policy "create own match" on public.games for insert to authenticated
  with check (p0 = auth.uid() and p1 is null);

-- only the two players in a match can make moves in it
drop policy if exists "players move" on public.games;
create policy "players move" on public.games for update to authenticated
  using (auth.uid() in (p0, p1)) with check (auth.uid() in (p0, p1));

-- players can never be swapped out, and turns only go forward
create or replace function public.games_guard() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.p0 is distinct from old.p0 then raise exception 'player 1 is fixed'; end if;
  if old.p1 is not null and new.p1 is distinct from old.p1 then raise exception 'player 2 is fixed'; end if;
  if old.p1 is null and new.p1 is not null and (new.p1 <> auth.uid() or new.p1 = new.p0) then
    raise exception 'you can only join as yourself';
  end if;
  if new.turn < old.turn then raise exception 'turns only go forward'; end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists games_guard on public.games;
create trigger games_guard before update on public.games for each row execute function public.games_guard();

-- joining: takes the free second seat, only if it is still free
create or replace function public.join_game(game_code text) returns public.games
language plpgsql security definer set search_path = '' as $$
declare g public.games;
begin
  update public.games set p1 = auth.uid(), status = 'active'
   where code = game_code and p1 is null and p0 <> auth.uid() and status <> 'over'
   returning * into g;
  if g.code is null then raise exception 'this match is full or finished'; end if;
  return g;
end $$;

grant select, insert, update on public.games to authenticated;
revoke all on function public.join_game(text) from public, anon;
grant execute on function public.join_game(text) to authenticated;

-- live updates when the other player moves
do $$ begin
  alter publication supabase_realtime add table public.games;
exception when duplicate_object then null; end $$;

-- ---------- play counter (no personal data: just what was played and when) ----------
create table if not exists public.plays (
  id         uuid primary key default gen_random_uuid(),
  mode       text not null check (mode in ('cpu', 'hot', 'online', 'watch')),
  biome      text check (char_length(biome) <= 20),
  created_at timestamptz not null default now()
);
alter table public.plays enable row level security;
drop policy if exists "log a play" on public.plays;
create policy "log a play" on public.plays for insert to authenticated with check (true);
grant insert on public.plays to authenticated;
-- no read access for players: you see the numbers in the Supabase dashboard
