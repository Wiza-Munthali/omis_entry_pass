-- OMIS Entry — operator roles from invites.
--
-- Supabase Auth's admin createUser inserts the user first and writes app_metadata in a
-- second step, so the insert trigger saw no role and made invited operators "staff".
-- When app_metadata gains (or changes) an operator role, apply it to the profile.
-- Only the service role can write app_metadata, so this cannot be used to self-promote;
-- later role changes by admins happen on profiles and do not touch app_metadata.

create function private.sync_operator_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text := new.raw_app_meta_data ->> 'role';
begin
  if v_role in ('admin', 'receptionist', 'guard') then
    update public.profiles
    set role = v_role::public.user_role
    where id = new.id and role is distinct from v_role::public.user_role;
  end if;
  return new;
end;
$$;

create trigger on_auth_user_role_set
after update of raw_app_meta_data on auth.users
for each row
when (old.raw_app_meta_data ->> 'role' is distinct from new.raw_app_meta_data ->> 'role')
execute function private.sync_operator_role();

-- Repair accounts invited before this fix.
update public.profiles p
set role = (u.raw_app_meta_data ->> 'role')::public.user_role
from auth.users u
where u.id = p.id
  and p.role = 'staff'
  and u.raw_app_meta_data ->> 'role' in ('admin', 'receptionist', 'guard');
