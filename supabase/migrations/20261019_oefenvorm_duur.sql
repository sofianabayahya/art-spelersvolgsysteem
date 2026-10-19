-- Duur van een oefenvorm in minuten (Ajax: max. 6 min voor vorm 1, max. 8 min voor vorm 2). Leeg = niet ingevuld.
alter table public.oefenvormen add column if not exists duur smallint check (duur is null or (duur > 0 and duur <= 90));
