-- Archief voor spelers (bv. gastspelers van een toernooi): niet weg, wel uit beeld. Alleen de hoofdtrainer ziet
-- gearchiveerde spelers (Instellingen → Archief) en zet ze met één tik terug. Oordelen, notities en beoordelingen blijven.
alter table public.players add column if not exists archived_at timestamptz;

drop policy if exists "Ingelogd leest actieve spelers; hoofdtrainer ook prullenbak" on public.players;
create policy "Ingelogd leest actieve spelers; hoofdtrainer ook prullenbak en archief" on public.players
  for select using (
    (select auth.uid()) is not null
    and ((deleted_at is null and archived_at is null) or (select public.is_hoofdtrainer()))
  );
