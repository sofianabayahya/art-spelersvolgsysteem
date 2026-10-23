-- Opvallende spelers per training: wat scouts (mondeling, na de training) of trainers is opgevallen. Sofian noteert het
-- en kopieert het naar SoccerLab. Alleen de hoofdtrainer leest en schrijft.
create table if not exists public.opvallend (
  id uuid primary key default gen_random_uuid(),
  training_date date not null,
  player_id uuid not null references public.players(id) on delete cascade,
  bron text,
  tekst text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_opvallend_datum on public.opvallend (training_date);
create index if not exists idx_opvallend_speler on public.opvallend (player_id);
alter table public.opvallend enable row level security;
create policy "Alleen hoofdtrainer: opvallend" on public.opvallend
  for all using ((select is_hoofdtrainer())) with check ((select is_hoofdtrainer()));
