-- Meten hoe de app gebruikt wordt (besluit Sofian 2026-10-27): welke schermen en vensters, en een paar acties
-- (vorm klaar, evaluatie opgeslagen, reflectie opgeslagen). Iedereen schrijft alleen zijn eigen regels; alleen de
-- hoofdtrainer leest. Regels ouder dan 180 dagen worden wekelijks opgeruimd.
create table if not exists public.gebruik (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  rol text,
  soort text not null check (soort in ('scherm','venster','actie')),
  naam text not null,
  datum date,                 -- trainingsdatum waar het over gaat (optioneel)
  created_at timestamptz not null default now()
);
create index if not exists idx_gebruik_tijd on public.gebruik (created_at);
alter table public.gebruik enable row level security;
create policy "Eigen gebruik vastleggen" on public.gebruik for insert
  with check (user_id = (select auth.uid()));
create policy "Hoofdtrainer leest gebruik" on public.gebruik for select
  using ((select is_hoofdtrainer()));

create or replace function public.gebruik_opruimen()
returns void language sql security definer set search_path = public as $$
  delete from public.gebruik where created_at < now() - interval '180 days';
$$;
revoke execute on function public.gebruik_opruimen() from public, anon, authenticated;
select cron.schedule('art-gebruik-opruimen', '15 4 * * 1', $$select public.gebruik_opruimen()$$);
