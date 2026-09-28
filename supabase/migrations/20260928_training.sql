-- Coachdashboard (tabblad Training), fase 1: voorbereiden en evalueren per oefenvorm.
-- Zichtbaar voor trainers en de hoofdtrainer, niet voor scouts.

-- Per training: rolverdeling en deadline om oefenvormen te delen.
create table if not exists public.training_plans (
  training_date date primary key,
  hoofd_a uuid references public.profiles(id) on delete set null,
  hoofd_b uuid references public.profiles(id) on delete set null,
  assistent uuid references public.profiles(id) on delete set null,
  deadline date,
  notitie text,
  updated_at timestamptz not null default now()
);

-- Oefenvorm: onderdeel A/B/C, vorm 1 of 2 (contextvorm x.1 / x.2), eigenaar, inhoud en evaluatie.
create table if not exists public.oefenvormen (
  id uuid primary key default gen_random_uuid(),
  training_date date not null,
  onderdeel text not null check (onderdeel in ('A','B','C')),
  volgnr int not null default 1 check (volgnr in (1,2)),
  eigenaar_id uuid references public.profiles(id) on delete set null,
  eigenaar_naam text,
  vaardigheid text,
  aantallen text,
  organisatie text,
  regels text,
  wedstrijdelement text,
  aanpassing_jong text,
  aanpassing_oud text,
  als_niet_loopt text,
  coachaccenten text,
  tekening_path text,
  status text not null default 'concept' check (status in ('concept','gedeeld')),
  eval_terug text check (eval_terug in ('ja','deels','nee')),
  eval_groep1 text,
  eval_aangepast text,
  eval_groep2 text,
  eval_ruimte text,
  eval_lichting text,
  eval_volgende text,
  updated_at timestamptz not null default now(),
  unique (training_date, onderdeel, volgnr)
);
create index if not exists idx_oefenvormen_datum on public.oefenvormen (training_date);
create index if not exists idx_oefenvormen_eigenaar on public.oefenvormen (eigenaar_id);

-- Tips en tops van collega's bij een oefenvorm.
create table if not exists public.oefenvorm_feedback (
  id uuid primary key default gen_random_uuid(),
  oefenvorm_id uuid not null references public.oefenvormen(id) on delete cascade,
  auteur_id uuid references public.profiles(id) on delete set null,
  auteur_naam text,
  soort text not null default 'tip' check (soort in ('tip','top')),
  tekst text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_oefenvorm_feedback_vorm on public.oefenvorm_feedback (oefenvorm_id);
create index if not exists idx_oefenvorm_feedback_auteur on public.oefenvorm_feedback (auteur_id);

-- Naam van eigenaar/auteur bewaren (leesbaar ook als het account verdwijnt).
create or replace function public.bewaar_training_naam()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'oefenvormen' then
    new.eigenaar_naam := coalesce((select naam from public.profiles where id = new.eigenaar_id), new.eigenaar_naam);
    new.updated_at := now();
  else
    new.auteur_naam := coalesce((select naam from public.profiles where id = new.auteur_id), new.auteur_naam);
  end if;
  return new;
end;
$$;
revoke execute on function public.bewaar_training_naam() from public, anon, authenticated;
drop trigger if exists trg_oefenvormen_naam on public.oefenvormen;
create trigger trg_oefenvormen_naam before insert or update on public.oefenvormen
  for each row execute function public.bewaar_training_naam();
drop trigger if exists trg_feedback_naam on public.oefenvorm_feedback;
create trigger trg_feedback_naam before insert or update on public.oefenvorm_feedback
  for each row execute function public.bewaar_training_naam();

-- Rechten: trainers en hoofdtrainer lezen alles; rolverdeling alleen hoofdtrainer;
-- oefenvorm wijzigen: eigenaar of hoofdtrainer; feedback: eigen feedback.
alter table public.training_plans enable row level security;
alter table public.oefenvormen enable row level security;
alter table public.oefenvorm_feedback enable row level security;

create policy "Trainers lezen trainingsplannen" on public.training_plans
  for select using ((select my_role()) in ('trainer','hoofdtrainer'));
create policy "Hoofdtrainer beheert trainingsplannen" on public.training_plans
  for all using ((select is_hoofdtrainer())) with check ((select is_hoofdtrainer()));

create policy "Trainers lezen oefenvormen" on public.oefenvormen
  for select using ((select my_role()) in ('trainer','hoofdtrainer'));
create policy "Trainers maken oefenvormen" on public.oefenvormen
  for insert with check ((select my_role()) in ('trainer','hoofdtrainer'));
create policy "Eigenaar of hoofdtrainer wijzigt oefenvorm" on public.oefenvormen
  for update using (eigenaar_id = (select auth.uid()) or eigenaar_id is null or (select is_hoofdtrainer()));
create policy "Hoofdtrainer verwijdert oefenvorm" on public.oefenvormen
  for delete using ((select is_hoofdtrainer()));

create policy "Trainers lezen feedback" on public.oefenvorm_feedback
  for select using ((select my_role()) in ('trainer','hoofdtrainer'));
create policy "Trainers geven feedback" on public.oefenvorm_feedback
  for insert with check (auteur_id = (select auth.uid()) and (select my_role()) in ('trainer','hoofdtrainer'));
create policy "Eigen feedback verwijderen" on public.oefenvorm_feedback
  for delete using (auteur_id = (select auth.uid()) or (select is_hoofdtrainer()));

-- Tekeningen van oefenvormen: afgeschermde opslag, alleen trainers en hoofdtrainer.
insert into storage.buckets (id, name, public) values ('training-images', 'training-images', false)
  on conflict (id) do nothing;
create policy "Trainers lezen trainingtekeningen" on storage.objects
  for select using (bucket_id = 'training-images' and (select public.my_role()) in ('trainer','hoofdtrainer'));
create policy "Trainers uploaden trainingtekeningen" on storage.objects
  for insert with check (bucket_id = 'training-images' and (select public.my_role()) in ('trainer','hoofdtrainer'));
create policy "Trainers wijzigen trainingtekeningen" on storage.objects
  for update using (bucket_id = 'training-images' and (select public.my_role()) in ('trainer','hoofdtrainer'));
create policy "Trainers verwijderen trainingtekeningen" on storage.objects
  for delete using (bucket_id = 'training-images' and (select public.my_role()) in ('trainer','hoofdtrainer'));

-- Periodisering (Ajax, seizoen 2026/27), per trainingsdatum: onderdeel A/B/C met vaardigheid en aantallen.
alter table public.app_settings add column if not exists periodisering jsonb;
