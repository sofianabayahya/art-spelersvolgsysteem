-- Fase 2 leeromgeving: reflectie van de trainer bij zijn oefenvorm (zichtbaar voor alle trainers)
-- en de reactie van de hoofdtrainer daarop (alleen zichtbaar voor die trainer en de hoofdtrainer).
alter table public.oefenvormen add column if not exists reflectie_goed text;
alter table public.oefenvormen add column if not exists reflectie_anders text;

create table if not exists public.reflectie_reacties (
  id uuid primary key default gen_random_uuid(),
  oefenvorm_id uuid not null unique references public.oefenvormen(id) on delete cascade,
  trainer_id uuid not null references public.profiles(id) on delete cascade,
  auteur_id uuid references public.profiles(id) on delete set null,
  tekst text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_reflectie_reacties_trainer on public.reflectie_reacties (trainer_id);
create index if not exists idx_reflectie_reacties_auteur on public.reflectie_reacties (auteur_id);

alter table public.reflectie_reacties enable row level security;
create policy "Trainer leest eigen reactie" on public.reflectie_reacties
  for select using (trainer_id = (select auth.uid()) or (select is_hoofdtrainer()));
create policy "Hoofdtrainer schrijft reacties" on public.reflectie_reacties
  for all using ((select is_hoofdtrainer())) with check ((select is_hoofdtrainer()));

-- Live bijwerken voor de trainingstabellen (stond nog niet aan).
do $$
declare t text;
begin
  foreach t in array array['training_plans','oefenvormen','oefenvorm_feedback','reflectie_reacties'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
