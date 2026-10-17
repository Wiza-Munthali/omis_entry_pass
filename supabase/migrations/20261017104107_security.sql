-- OMIS Entry — roles, RLS and grants (docs/SPEC.md → Roles and permissions, Row Level Security).
--
-- Two layers on every table:
--   1. Grants decide which statements a client role may run at all.
--      anon gets nothing: visitor portal writes go through Edge Functions (service role).
--      authenticated never gets INSERT/UPDATE/DELETE on people, vehicles, passes or visits:
--      those change only through RPCs (Phase 2) or Edge Functions.
--   2. RLS policies decide which rows each operator role and staff member can see or change.

grant usage on schema private to authenticated;

-- ---------------------------------------------------------------------------
-- Role helpers
-- ---------------------------------------------------------------------------

-- Operator rank: guard 1 < receptionist 2 < admin 3. Staff are pass holders, rank 0.
create function private.role_rank(r public.user_role)
returns int
language sql
immutable
set search_path = ''
as $$
  select case r
    when 'admin' then 3
    when 'receptionist' then 2
    when 'guard' then 1
    else 0
  end;
$$;

-- True when the signed-in user is an active operator at or above min_role.
-- The role is always read from profiles via auth.uid(), never from the client.
create function private.has_role(min_role public.user_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_active
      and private.role_rank(p.role) >= private.role_rank(min_role)
      and private.role_rank(min_role) > 0
  );
$$;

-- The people.id linked to the signed-in staff member, if any.
create function private.my_person_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select id from public.people where profile_id = auth.uid();
$$;

-- A guard may attach an ID photo only to a pending gate request they created.
create function private.can_attach_id_photo(p_pass_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.passes
    where id = p_pass_id
      and status = 'pending'
      and source = 'gate'
      and requested_by = auth.uid()
  );
$$;

-- Receptionists see ID photos only for requests they are deciding:
-- still pending (in their queue) or decided by them.
create function private.is_deciding(p_pass_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.passes
    where id = p_pass_id
      and (status = 'pending' or decided_by = auth.uid())
  );
$$;

-- ---------------------------------------------------------------------------
-- Profiles: created from auth.users, protected columns
-- ---------------------------------------------------------------------------

-- Every new auth user gets a profile. The role comes from app_metadata, which only
-- the service role can set (admin invites, seed); user_metadata is ignored for roles.
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested text := new.raw_app_meta_data ->> 'role';
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    case
      when requested in ('admin', 'receptionist', 'guard') then requested::public.user_role
      else 'staff'
    end
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();

create function private.sync_profile_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles set email = new.email where id = new.id;
  return new;
end;
$$;

create trigger on_auth_user_email_changed
after update of email on auth.users
for each row
when (old.email is distinct from new.email)
execute function private.sync_profile_email();

-- Only admins change role or is_active, and never their own (avoids locking out the last admin).
-- Server-side callers with no auth.uid() (service role, migrations) are not restricted.
create function private.protect_profile_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if new.role is distinct from old.role or new.is_active is distinct from old.is_active then
    if not private.has_role('admin') then
      raise exception 'only admins can change role or is_active' using errcode = '42501';
    end if;
    if new.id = auth.uid() then
      raise exception 'admins cannot change their own role or deactivate themselves' using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

create trigger profiles_protect_columns
before update on public.profiles
for each row execute function private.protect_profile_columns();

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

-- Later migrations must grant explicitly; nothing is exposed by default.
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public revoke execute on functions from public, anon, authenticated;

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

grant select on
  public.profiles,
  public.people,
  public.vehicles,
  public.passes,
  public.visits,
  public.gates,
  public.id_photos,
  public.flags,
  public.settings,
  public.audit_log
to authenticated;

-- Profiles: own name, phone and push token; role and is_active (admins only, enforced above).
grant update (full_name, phone, fcm_token, role, is_active) on public.profiles to authenticated;

-- ID photos: the client supplies only which pass and where the file is.
-- uploaded_by defaults to auth.uid() and delete_after is set by trigger.
grant insert (pass_id, storage_path) on public.id_photos to authenticated;

-- Admin-managed configuration.
grant insert, update, delete on public.gates to authenticated;
grant update (
  org_name,
  allowed_email_domains,
  approval_timeout_minutes,
  auto_close_time,
  id_photo_retention_days,
  staff_pass_days,
  week_pass_days
) on public.settings to authenticated;
grant update (resolved_by, resolved_at) on public.flags to authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.people enable row level security;
alter table public.vehicles enable row level security;
alter table public.passes enable row level security;
alter table public.visits enable row level security;
alter table public.gates enable row level security;
alter table public.id_photos enable row level security;
alter table public.flags enable row level security;
alter table public.settings enable row level security;
alter table public.audit_log enable row level security;

-- profiles: users read and update their own row; admins read and update all.
create policy "profiles: read own or admin"
on public.profiles for select to authenticated
using (id = (select auth.uid()) or (select private.has_role('admin')));

create policy "profiles: update own or admin"
on public.profiles for update to authenticated
using (id = (select auth.uid()) or (select private.has_role('admin')))
with check (id = (select auth.uid()) or (select private.has_role('admin')));

-- people, vehicles, passes: staff read their own; receptionists and admins read all.
-- Guards have no direct read; they use the scan RPC and the on_site view.
create policy "people: read own or receptionist"
on public.people for select to authenticated
using (profile_id = (select auth.uid()) or (select private.has_role('receptionist')));

create policy "vehicles: read own or receptionist"
on public.vehicles for select to authenticated
using (person_id = (select private.my_person_id()) or (select private.has_role('receptionist')));

create policy "passes: read own or receptionist"
on public.passes for select to authenticated
using (person_id = (select private.my_person_id()) or (select private.has_role('receptionist')));

-- visits: guards read open visits (on-site list); receptionists and admins read all.
create policy "visits: guards read open, receptionists read all"
on public.visits for select to authenticated
using (
  (select private.has_role('receptionist'))
  or ((select private.has_role('guard')) and exit_at is null)
);

-- gates: operators read; admins write.
create policy "gates: operators read"
on public.gates for select to authenticated
using ((select private.has_role('guard')));

create policy "gates: admins insert"
on public.gates for insert to authenticated
with check ((select private.has_role('admin')));

create policy "gates: admins update"
on public.gates for update to authenticated
using ((select private.has_role('admin')))
with check ((select private.has_role('admin')));

create policy "gates: admins delete"
on public.gates for delete to authenticated
using ((select private.has_role('admin')));

-- settings: operators read; admins update.
create policy "settings: operators read"
on public.settings for select to authenticated
using ((select private.has_role('guard')));

create policy "settings: admins update"
on public.settings for update to authenticated
using ((select private.has_role('admin')))
with check ((select private.has_role('admin')));

-- id_photos: guards insert for their own pending gate requests; receptionists read
-- photos for requests they are deciding; admins read all.
create policy "id_photos: guards insert for own gate request"
on public.id_photos for insert to authenticated
with check (
  (select private.has_role('guard'))
  and uploaded_by = (select auth.uid())
  and private.can_attach_id_photo(pass_id)
);

create policy "id_photos: receptionists read deciding, admins read all"
on public.id_photos for select to authenticated
using (
  (select private.has_role('admin'))
  or ((select private.has_role('receptionist')) and private.is_deciding(pass_id))
);

-- flags: admins read and resolve.
create policy "flags: admins read"
on public.flags for select to authenticated
using ((select private.has_role('admin')));

create policy "flags: admins resolve"
on public.flags for update to authenticated
using ((select private.has_role('admin')))
with check ((select private.has_role('admin')));

-- audit_log: admins read. No write policy: rows come from triggers and RPCs only.
create policy "audit_log: admins read"
on public.audit_log for select to authenticated
using ((select private.has_role('admin')));
