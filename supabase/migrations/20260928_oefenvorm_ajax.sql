-- Oefenvorm volgens de Ajax Training planner: deel 1 (bewegingsvariaties, rondes x1.1 en x1.2) en
-- deel 2 (contextvorm, rondes x2.1 en x2.2 met contextvariatie). Tekening blijft bewerkbaar via tekening_json.
alter table public.oefenvormen add column if not exists variatie_1 text;
alter table public.oefenvormen add column if not exists variatie_2 text;
alter table public.oefenvormen add column if not exists tekening_json jsonb;
