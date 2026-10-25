-- Evaluatie vanuit impliciet leren (constraints-led), besluit Sofian 2026-10-25.
-- Groepen per training (welke lichtingen samen trainen) en per vorm (welke groepen deden deze vorm).
alter table public.training_plans add column if not exists groepen jsonb;     -- [["l2019"], ["l2018","l2017","l2016"]]
alter table public.training_plans add column if not exists evaluatie jsonb;   -- training als geheel: { transfer, cijfer, opmerking }
alter table public.oefenvormen add column if not exists groepen jsonb;        -- ["l2019", "l2018+l2017+l2016"]; leeg = alle groepen
alter table public.oefenvormen add column if not exists evaluatie jsonb;      -- { per: {groep: {liep, terug, uitdaging, tempo}}, knoppen, effect, knop_tekst, echt, volgende }

-- Reflectie van de trainer: één per training. Alle trainers lezen elkaars reflectie; schrijven doet de trainer zelf.
create table if not exists public.reflecties (
  id uuid primary key default gen_random_uuid(),
  training_date date not null,
  trainer_id uuid not null references public.profiles(id) on delete cascade,
  focus text[] not null default '{}',
  knop text, gezien text, woorden text, volgende text,
  updated_at timestamptz not null default now(),
  unique (training_date, trainer_id)
);
alter table public.reflecties enable row level security;
create policy "Trainers lezen reflecties" on public.reflecties for select
  using ((select my_role()) = any (array['trainer','hoofdtrainer']));
create policy "Trainer schrijft eigen reflectie" on public.reflecties for insert
  with check (trainer_id = (select auth.uid()) or (select is_hoofdtrainer()));
create policy "Trainer wijzigt eigen reflectie" on public.reflecties for update
  using (trainer_id = (select auth.uid()) or (select is_hoofdtrainer()));
create policy "Trainer of hoofdtrainer verwijdert reflectie" on public.reflecties for delete
  using (trainer_id = (select auth.uid()) or (select is_hoofdtrainer()));

-- Reactie van de hoofdtrainer op een reflectie: alleen die trainer (en de hoofdtrainer) leest hem.
create table if not exists public.reflectie_reactie (
  reflectie_id uuid primary key references public.reflecties(id) on delete cascade,
  trainer_id uuid not null references public.profiles(id) on delete cascade,
  tekst text not null,
  updated_at timestamptz not null default now()
);
alter table public.reflectie_reactie enable row level security;
create policy "Hoofdtrainer schrijft reactie" on public.reflectie_reactie for all
  using ((select is_hoofdtrainer())) with check ((select is_hoofdtrainer()));
create policy "Trainer leest reactie op eigen reflectie" on public.reflectie_reactie for select
  using (trainer_id = (select auth.uid()) or (select is_hoofdtrainer()));

-- Werkpunt per trainer (vervangt besluit 2026-09-28 "geen leerdoel"): de hoofdtrainer zet het, de trainer ziet zijn eigen.
create table if not exists public.werkpunten (
  trainer_id uuid primary key references public.profiles(id) on delete cascade,
  tekst text not null,
  updated_at timestamptz not null default now()
);
alter table public.werkpunten enable row level security;
create policy "Hoofdtrainer beheert werkpunten" on public.werkpunten for all
  using ((select is_hoofdtrainer())) with check ((select is_hoofdtrainer()));
create policy "Trainer leest eigen werkpunt" on public.werkpunten for select
  using (trainer_id = (select auth.uid()) or (select is_hoofdtrainer()));

-- Opvallende spelers labelen met het TIPS-model van Ajax (Techniek, Inzicht, Persoonlijkheid, Snelheid).
alter table public.opvallend add column if not exists tips text[] not null default '{}';
