-- 1. Beoordelingen en evaluaties blijven bestaan als een account wordt verwijderd (was: meeverwijderd).
--    De naam van de beoordelaar wordt bij elke beoordeling bewaard, zodat het rapport leesbaar blijft.
alter table public.scores add column if not exists trainer_naam text;
alter table public.evaluations add column if not exists trainer_naam text;
alter table public.scout_reports add column if not exists scout_naam text;

alter table public.scores drop constraint if exists scores_trainer_id_fkey;
alter table public.scores add constraint scores_trainer_id_fkey
  foreign key (trainer_id) references public.profiles(id) on delete set null;
alter table public.evaluations drop constraint if exists evaluations_trainer_id_fkey;
alter table public.evaluations add constraint evaluations_trainer_id_fkey
  foreign key (trainer_id) references public.profiles(id) on delete set null;

create or replace function public.bewaar_beoordelaar_naam()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'scout_reports' then
    new.scout_naam := coalesce((select naam from public.profiles where id = new.scout_id), new.scout_naam);
  else
    new.trainer_naam := coalesce((select naam from public.profiles where id = new.trainer_id), new.trainer_naam);
  end if;
  return new;
end;
$$;
revoke execute on function public.bewaar_beoordelaar_naam() from public, anon, authenticated;

drop trigger if exists trg_scores_naam on public.scores;
create trigger trg_scores_naam before insert or update on public.scores
  for each row execute function public.bewaar_beoordelaar_naam();
drop trigger if exists trg_evaluations_naam on public.evaluations;
create trigger trg_evaluations_naam before insert or update on public.evaluations
  for each row execute function public.bewaar_beoordelaar_naam();
drop trigger if exists trg_scout_reports_naam on public.scout_reports;
create trigger trg_scout_reports_naam before insert or update on public.scout_reports
  for each row execute function public.bewaar_beoordelaar_naam();

update public.scores s set trainer_naam = p.naam from public.profiles p where p.id = s.trainer_id and s.trainer_naam is null;
update public.evaluations e set trainer_naam = p.naam from public.profiles p where p.id = e.trainer_id and e.trainer_naam is null;

-- 2. Seizoen instelbaar: trainingsdata (met blok) en lichtingen, beheerd door de hoofdtrainer in Instellingen.
alter table public.app_settings add column if not exists training_dates jsonb;
alter table public.app_settings add column if not exists lichtingen jsonb;
update public.app_settings set
  training_dates = coalesce(training_dates, '[
    {"date":"2026-09-13","blok":1},{"date":"2026-09-20","blok":1},{"date":"2026-09-27","blok":1},{"date":"2026-10-04","blok":1},
    {"date":"2026-10-25","blok":2},{"date":"2026-11-01","blok":2},{"date":"2026-11-08","blok":2},{"date":"2026-11-15","blok":2},
    {"date":"2026-11-22","blok":2},{"date":"2026-11-29","blok":2},{"date":"2026-12-06","blok":2},
    {"date":"2027-01-24","blok":3},{"date":"2027-01-31","blok":3},{"date":"2027-02-07","blok":3},{"date":"2027-02-14","blok":3},
    {"date":"2027-02-28","blok":4},{"date":"2027-03-07","blok":4},{"date":"2027-03-14","blok":4},{"date":"2027-03-21","blok":4},
    {"date":"2027-04-04","blok":4},{"date":"2027-04-11","blok":4},{"date":"2027-04-18","blok":4}
  ]'::jsonb),
  lichtingen = coalesce(lichtingen, '[{"key":"l2016","label":"2016"},{"key":"l2017","label":"2017"},{"key":"l2018","label":"2018"},{"key":"l2019","label":"2019"}]'::jsonb)
where id = 1;
