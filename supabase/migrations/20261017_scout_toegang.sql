-- Scout-toegang per bezoek: de hoofdtrainer geeft een scout "toegang voor vandaag" (manage-users, actie grant_day).
-- Dat zet app_metadata.toegang_tot = nu + 24 uur. Deze taak zet elk kwartier verlopen accounts weer uit
-- (Supabase-ban) en beëindigt hun sessies, ook als niemand de app open heeft.
create or replace function public.scout_toegang_verlopen()
returns integer language plpgsql security definer set search_path = public, auth as $$
declare n integer;
begin
  with verlopen as (
    update auth.users
       set banned_until = now() + interval '100 years',
           raw_app_meta_data = raw_app_meta_data - 'toegang_tot'
     where raw_app_meta_data ? 'toegang_tot'
       and nullif(raw_app_meta_data->>'toegang_tot', '') is not null
       and (raw_app_meta_data->>'toegang_tot')::timestamptz < now()
    returning id
  ), weg as (
    delete from auth.sessions s using verlopen v where s.user_id = v.id returning 1
  )
  select count(*) into n from verlopen;
  return n;
end $$;
revoke execute on function public.scout_toegang_verlopen() from public, anon, authenticated;

select cron.schedule('art-scout-toegang', '*/15 * * * *', $$select public.scout_toegang_verlopen()$$);
