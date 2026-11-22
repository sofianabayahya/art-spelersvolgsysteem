-- 1) Tweede vorm bij C (besluit Sofian 2026-11-22): C2b = volgnr 3 (alleen bij onderdeel C). Bestaande rijen blijven gelijk.
alter table public.oefenvormen drop constraint if exists oefenvormen_volgnr_check;
alter table public.oefenvormen add constraint oefenvormen_volgnr_check
  check (volgnr = any (array[1, 2]) or (volgnr = 3 and onderdeel = 'C'));

-- 2) 360-gradenfeedback (halfjaarevaluatie, besluit Sofian 2026-11-22). Iedereen (trainers + hoofdtrainer) vult in
--    over zichzelf, over elke collega en over de hoofdtrainer. Collega's zijn anoniem: een trainer ziet alleen het
--    gemiddelde en de teksten zonder naam (via feedback_uitslag), en pas als de ronde gesloten is.
create table if not exists public.feedback_rondes (
  id uuid primary key default gen_random_uuid(),
  titel text not null,
  open_tot date,
  gesloten boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.feedback_antwoorden (
  id uuid primary key default gen_random_uuid(),
  ronde_id uuid not null references public.feedback_rondes(id) on delete cascade,
  van_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  over_id uuid not null references public.profiles(id) on delete cascade,
  scores jsonb not null default '{}'::jsonb,   -- {sleutel: 1..4} (1 zelden, 2 soms, 3 vaak, 4 bijna altijd)
  top text,
  tip text,
  extra jsonb not null default '{}'::jsonb,    -- alleen bij jezelf: groei, ontwikkelpunt, door, rol, nodig
  updated_at timestamptz not null default now(),
  unique (ronde_id, van_id, over_id)
);
alter table public.feedback_rondes enable row level security;
alter table public.feedback_antwoorden enable row level security;

create policy "Trainers lezen feedbackrondes" on public.feedback_rondes for select
  using ((select my_role()) = any (array['trainer','hoofdtrainer']));
create policy "Hoofdtrainer beheert feedbackrondes" on public.feedback_rondes for all
  using ((select is_hoofdtrainer())) with check ((select is_hoofdtrainer()));

create policy "Eigen feedback of hoofdtrainer leest" on public.feedback_antwoorden for select
  using (van_id = (select auth.uid()) or (select is_hoofdtrainer()));
create policy "Eigen feedback geven" on public.feedback_antwoorden for insert
  with check (van_id = (select auth.uid()) and (select my_role()) = any (array['trainer','hoofdtrainer'])
    and exists (select 1 from public.feedback_rondes r where r.id = ronde_id and not r.gesloten));
create policy "Eigen feedback wijzigen" on public.feedback_antwoorden for update
  using (van_id = (select auth.uid()) and (select my_role()) = any (array['trainer','hoofdtrainer'])
    and exists (select 1 from public.feedback_rondes r where r.id = ronde_id and not r.gesloten))
  with check (van_id = (select auth.uid()));
create policy "Hoofdtrainer verwijdert feedback" on public.feedback_antwoorden for delete
  using ((select is_hoofdtrainer()));

-- Uitslag over één persoon: eigen antwoord, dat van de hoofdtrainer (met naam) en de collega's samengevat (anoniem).
-- Een trainer mag alleen zijn eigen uitslag opvragen, en pas als de ronde gesloten is. De hoofdtrainer mag alles.
create or replace function public.feedback_uitslag(p_ronde uuid, p_over uuid default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_over uuid := coalesce(p_over, auth.uid());
  v_hoofd boolean := is_hoofdtrainer();
  v_zelf jsonb; v_hfd jsonb; v_col jsonb;
begin
  if v_over is distinct from auth.uid() and not v_hoofd then raise exception 'Geen toegang'; end if;
  if not v_hoofd and not exists (select 1 from feedback_rondes where id = p_ronde and gesloten) then return null; end if;
  select jsonb_build_object('scores', scores, 'top', top, 'tip', tip, 'extra', extra) into v_zelf
    from feedback_antwoorden where ronde_id = p_ronde and over_id = v_over and van_id = v_over;
  select jsonb_agg(jsonb_build_object('naam', p.naam, 'scores', a.scores, 'top', a.top, 'tip', a.tip)) into v_hfd
    from feedback_antwoorden a join profiles p on p.id = a.van_id
    where a.ronde_id = p_ronde and a.over_id = v_over and a.van_id <> v_over and p.role = 'hoofdtrainer';
  with col as (
    select a.* from feedback_antwoorden a join profiles p on p.id = a.van_id
    where a.ronde_id = p_ronde and a.over_id = v_over and a.van_id <> v_over and p.role <> 'hoofdtrainer'
  )
  select jsonb_build_object(
    'n', (select count(*) from col),
    'gem', coalesce((select jsonb_object_agg(k, g) from (
       select e.key k, round(avg(e.value::numeric), 2) g
       from col, jsonb_each_text(col.scores) e where e.value ~ '^[1-4]$' group by e.key) s), '{}'::jsonb),
    'tops', coalesce((select jsonb_agg(top order by random()) from col where coalesce(top, '') <> ''), '[]'::jsonb),
    'tips', coalesce((select jsonb_agg(tip order by random()) from col where coalesce(tip, '') <> ''), '[]'::jsonb)
  ) into v_col;
  return jsonb_build_object('zelf', v_zelf, 'hoofd', coalesce(v_hfd, '[]'::jsonb), 'collegas', v_col);
end $$;
revoke execute on function public.feedback_uitslag(uuid, uuid) from public, anon;
grant execute on function public.feedback_uitslag(uuid, uuid) to authenticated;
