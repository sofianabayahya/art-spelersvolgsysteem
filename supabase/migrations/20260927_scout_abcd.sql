-- Scouts vullen de Ajax-lijst in: Wedstrijdbeoordeling + Potentieel (A/B/C/D), Rank (#1 top 3 / #3 onderste 3),
-- Advies (1 uitstroom, 2 doorstroom, 3 vervolg AVS, 4 direct aannemen) + notitie.
-- Scouts zien alleen hun eigen beoordelingen; de hoofdtrainer ziet alles.
-- Drempel voor het scout-signaal is instelbaar door de hoofdtrainer.

alter table public.scout_reports
  add column if not exists wedstrijdbeoordeling text check (wedstrijdbeoordeling in ('A','B','C','D')),
  add column if not exists potentieel text check (potentieel in ('A','B','C','D')),
  add column if not exists rank text check (rank in ('1','3')),
  add column if not exists advies text check (advies in ('1','2','3','4'));

alter table public.app_settings
  add column if not exists scout_signaal_drempel integer not null default 3
    check (scout_signaal_drempel between 1 and 20);

drop policy if exists "Scout en hoofdtrainer lezen scoutrapporten" on public.scout_reports;
create policy "Scout leest eigen scoutrapporten; hoofdtrainer leest alle" on public.scout_reports
  for select using ((scout_id = auth.uid() and my_role() = 'scout') or is_hoofdtrainer());

drop policy if exists "Scout of hoofdtrainer voegt scoutrapport toe" on public.scout_reports;
create policy "Scout of hoofdtrainer voegt eigen scoutrapport toe" on public.scout_reports
  for insert with check (scout_id = auth.uid() and my_role() = any (array['scout','hoofdtrainer']));
