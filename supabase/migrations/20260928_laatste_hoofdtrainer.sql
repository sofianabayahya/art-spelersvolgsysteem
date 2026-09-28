-- Vangnet: de laatste hoofdtrainer kan niet (per ongeluk) van rol veranderen of verwijderd worden.
create or replace function public.bewaak_laatste_hoofdtrainer()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.role = 'hoofdtrainer'
     and (tg_op = 'DELETE' or new.role is distinct from 'hoofdtrainer')
     and not exists (select 1 from public.profiles where role = 'hoofdtrainer' and id <> old.id) then
    raise exception 'Er moet altijd minstens één hoofdtrainer zijn';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;
revoke execute on function public.bewaak_laatste_hoofdtrainer() from public, anon, authenticated;
drop trigger if exists trg_laatste_hoofdtrainer on public.profiles;
create trigger trg_laatste_hoofdtrainer before update or delete on public.profiles
  for each row execute function public.bewaak_laatste_hoofdtrainer();
