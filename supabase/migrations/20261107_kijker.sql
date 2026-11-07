-- Rol "kijker" (besluit Sofian 2026-11-07, voor de coördinator van Ajax): ziet wat trainers zien, maar alleen lezen.
-- De database weigert elke wijziging; toegang is tijdelijk (zoals scouts: app_metadata.toegang_tot + art-scout-toegang).
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role = any (array['hoofdtrainer','trainer','scout','kijker']));

-- Lezen: de trainingsonderdelen die trainers ook lezen (niet: reacties, werkpunten, rapport, scouting, opvallend).
drop policy if exists "Trainers lezen trainingsplannen" on public.training_plans;
create policy "Trainers lezen trainingsplannen" on public.training_plans for select
  using ((select my_role()) = any (array['trainer','hoofdtrainer','kijker']));
drop policy if exists "Trainers lezen oefenvormen" on public.oefenvormen;
create policy "Trainers lezen oefenvormen" on public.oefenvormen for select
  using ((select my_role()) = any (array['trainer','hoofdtrainer','kijker']));
drop policy if exists "Trainers lezen feedback" on public.oefenvorm_feedback;
create policy "Trainers lezen feedback" on public.oefenvorm_feedback for select
  using ((select my_role()) = any (array['trainer','hoofdtrainer','kijker']));
drop policy if exists "Trainers lezen reflecties" on public.reflecties;
create policy "Trainers lezen reflecties" on public.reflecties for select
  using ((select my_role()) = any (array['trainer','hoofdtrainer','kijker']));
drop policy if exists "Trainers lezen trainingtekeningen" on storage.objects;
create policy "Trainers lezen trainingtekeningen" on storage.objects for select
  using (bucket_id = 'training-images' and (select my_role()) = any (array['trainer','hoofdtrainer','kijker']));

-- Schrijven: gaten dichten die alleen op "eigen rij" controleerden, zodat een kijker niets kan opslaan.
drop policy if exists "Trainer schrijft eigen reflectie" on public.reflecties;
create policy "Trainer schrijft eigen reflectie" on public.reflecties for insert
  with check ((trainer_id = (select auth.uid()) and (select my_role()) = any (array['trainer','hoofdtrainer'])) or (select is_hoofdtrainer()));
drop policy if exists "Trainer wijzigt eigen reflectie" on public.reflecties;
create policy "Trainer wijzigt eigen reflectie" on public.reflecties for update
  using ((trainer_id = (select auth.uid()) and (select my_role()) = any (array['trainer','hoofdtrainer'])) or (select is_hoofdtrainer()));
drop policy if exists "Eigenaar of hoofdtrainer wijzigt oefenvorm" on public.oefenvormen;
create policy "Eigenaar of hoofdtrainer wijzigt oefenvorm" on public.oefenvormen for update
  using ((select my_role()) = any (array['trainer','hoofdtrainer'])
    and (eigenaar_id = (select auth.uid()) or eigenaar_id is null or (select is_hoofdtrainer())));
drop policy if exists "Eigen favoriet toevoegen" on public.player_favorites;
create policy "Eigen favoriet toevoegen" on public.player_favorites for insert
  with check (user_id = auth.uid() and my_role() = any (array['trainer','hoofdtrainer','scout']));
