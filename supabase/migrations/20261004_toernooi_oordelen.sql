-- Toernooi-nabespreking (alleen hoofdtrainer): beoordelaars per toernooi, oordelen -2..+2 per speler per beoordelaar,
-- en één toelichting per speler. Scouts werken op papier; de hoofdtrainer noteert in de app.
create table if not exists public.toernooi_nabespreking (
  toernooi_datum date primary key,
  beoordelaars jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);
create table if not exists public.toernooi_oordelen (
  id uuid primary key default gen_random_uuid(),
  toernooi_datum date not null,
  player_id uuid not null references public.players(id) on delete cascade,
  beoordelaar text not null,
  rol text not null check (rol in ('scout','trainer')),
  waarde int not null check (waarde between -2 and 2),
  updated_at timestamptz not null default now(),
  unique (toernooi_datum, player_id, beoordelaar)
);
create index if not exists idx_toernooi_oordelen_speler on public.toernooi_oordelen (player_id);
create table if not exists public.toernooi_notities (
  toernooi_datum date not null,
  player_id uuid not null references public.players(id) on delete cascade,
  tekst text,
  updated_at timestamptz not null default now(),
  primary key (toernooi_datum, player_id)
);
create index if not exists idx_toernooi_notities_speler on public.toernooi_notities (player_id);
alter table public.toernooi_nabespreking enable row level security;
alter table public.toernooi_oordelen enable row level security;
alter table public.toernooi_notities enable row level security;
create policy "Alleen hoofdtrainer: nabespreking" on public.toernooi_nabespreking
  for all using ((select is_hoofdtrainer())) with check ((select is_hoofdtrainer()));
create policy "Alleen hoofdtrainer: oordelen" on public.toernooi_oordelen
  for all using ((select is_hoofdtrainer())) with check ((select is_hoofdtrainer()));
create policy "Alleen hoofdtrainer: notities" on public.toernooi_notities
  for all using ((select is_hoofdtrainer())) with check ((select is_hoofdtrainer()));
