-- Eén scoutbeoordeling per scout, per speler, per blok (vangnet tegen dubbel opslaan).
create unique index if not exists uq_scout_reports_scout_player_blok on public.scout_reports (scout_id, player_id, blok);
