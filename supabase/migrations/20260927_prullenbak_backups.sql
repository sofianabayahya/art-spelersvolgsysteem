-- 1. Prullenbak: spelers worden eerst 30 dagen "verwijderd gemarkeerd" (deleted_at) voordat ze echt weg zijn.
--    Trainers en scouts zien verwijderde spelers niet; de hoofdtrainer ziet ze in de prullenbak.
alter table public.players add column if not exists deleted_at timestamptz;

drop policy if exists "Iedereen ingelogd leest spelers" on public.players;
create policy "Ingelogd leest actieve spelers; hoofdtrainer ook prullenbak" on public.players
  for select using ((select auth.uid()) is not null and (deleted_at is null or (select is_hoofdtrainer())));

create or replace function public.purge_player_trash()
returns void language sql security definer set search_path = public as $$
  delete from public.players where deleted_at < now() - interval '30 days';
$$;
revoke execute on function public.purge_player_trash() from public, anon, authenticated;

-- 2. Eigen wekelijkse back-up (naast de dagelijkse back-up van Supabase Pro): een momentopname van alle
--    tabellen als JSON, laatste 26 bewaard. De hoofdtrainer kan ze downloaden of er zelf een maken.
create table if not exists public.backups (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  soort text not null default 'automatisch' check (soort in ('automatisch', 'handmatig')),
  data jsonb not null
);
alter table public.backups enable row level security;
drop policy if exists "Alleen hoofdtrainer leest back-ups" on public.backups;
create policy "Alleen hoofdtrainer leest back-ups" on public.backups
  for select using ((select is_hoofdtrainer()));

create or replace function public.make_backup(p_soort text default 'automatisch')
returns bigint language plpgsql security definer set search_path = public as $$
declare new_id bigint;
begin
  -- Geplande taak draait zonder gebruiker; vanuit de app mag alleen de hoofdtrainer.
  if auth.uid() is not null and not is_hoofdtrainer() then
    raise exception 'Alleen de hoofdtrainer kan een back-up maken';
  end if;
  insert into public.backups (soort, data)
  select p_soort, jsonb_build_object(
    'gemaakt', now(),
    'players', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from public.players t),
    'scores', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from public.scores t),
    'evaluations', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from public.evaluations t),
    'scout_reports', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from public.scout_reports t),
    'cancelled_trainings', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from public.cancelled_trainings t),
    'player_favorites', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from public.player_favorites t),
    'profiles', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from public.profiles t),
    'app_settings', (select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from public.app_settings t)
  )
  returning id into new_id;
  delete from public.backups where id not in (select id from public.backups order by created_at desc limit 26);
  return new_id;
end;
$$;
revoke execute on function public.make_backup(text) from public, anon;
grant execute on function public.make_backup(text) to authenticated;

create extension if not exists pg_cron;
select cron.schedule('art-wekelijkse-backup', '0 3 * * 1', $$select public.make_backup('automatisch')$$);
select cron.schedule('art-prullenbak-legen', '30 3 * * *', $$select public.purge_player_trash()$$);

-- 3. Beveiliging (Supabase-advies): functies niet aanroepbaar zonder in te loggen.
revoke execute on function public.set_attendance(uuid, date, jsonb) from public, anon;
grant execute on function public.set_attendance(uuid, date, jsonb) to authenticated;
revoke execute on function public.enforce_max_favorites() from public, anon, authenticated; -- alleen als trigger

-- 4. Snelheid (Supabase-advies): indexen op koppelingen.
create index if not exists idx_evaluations_trainer on public.evaluations (trainer_id);
create index if not exists idx_player_favorites_user on public.player_favorites (user_id);
create index if not exists idx_scores_trainer on public.scores (trainer_id);
create index if not exists idx_scout_reports_scout on public.scout_reports (scout_id);
