-- OMIS Entry — staff portal support (docs/SPEC.md → Core flows → 1. Staff pass).

-- ---------------------------------------------------------------------------
-- Auth hook: reject sign-ups from email domains not in settings.allowed_email_domains.
-- Wired up in config.toml ([auth.hook.before_user_created]) and, in hosted projects,
-- under Authentication → Hooks. Operators invited by an admin carry a role in
-- app_metadata (only settable server-side) and may use any address.
-- ---------------------------------------------------------------------------
create function private.email_domain_allowed(p_email text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select lower(split_part(p_email, '@', 2)) = any (
    select lower(d) from public.settings s, unnest(s.allowed_email_domains) d
  );
$$;

create function private.before_user_created(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_email text := event -> 'user' ->> 'email';
  v_role text := event -> 'user' -> 'app_metadata' ->> 'role';
begin
  if v_role in ('admin', 'receptionist', 'guard') then
    return '{}'::jsonb;
  end if;
  if v_email is not null and private.email_domain_allowed(v_email) then
    return '{}'::jsonb;
  end if;
  return jsonb_build_object('error', jsonb_build_object(
    'http_code', 403,
    'message', 'Use your work email address to get a staff pass.'
  ));
end;
$$;

grant usage on schema private to supabase_auth_admin;
revoke execute on function private.before_user_created(jsonb) from public, anon, authenticated;
grant execute on function private.before_user_created(jsonb) to supabase_auth_admin;

-- ---------------------------------------------------------------------------
-- Public portal settings: what the sign-in page shows before anyone is signed in
-- (organisation name and the allowed email domains for the helper text).
-- ---------------------------------------------------------------------------
create function public.portal_config()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'org_name', s.org_name,
    'allowed_email_domains', to_jsonb(s.allowed_email_domains)
  )
  from public.settings s;
$$;

comment on function public.portal_config is 'Organisation name and allowed staff email domains, for the public portal.';

revoke execute on function public.portal_config() from public;
grant execute on function public.portal_config() to anon, authenticated;

-- register_staff_pass uses the same domain check.
create or replace function public.register_staff_pass(
  p_full_name text,
  p_id_number text,
  p_plate text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles;
  v_staff_days int;
  v_name text := private.clean(p_full_name);
  v_id_number text := private.normalize_id_number(p_id_number);
  v_person_id uuid;
  v_vehicle_id uuid;
  v_pass public.passes;
begin
  select * into v_profile from public.profiles where id = v_uid and is_active;
  if not found then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  if not private.email_domain_allowed(v_profile.email) then
    raise exception 'email_domain_not_allowed' using errcode = '42501';
  end if;

  if v_name is null then
    raise exception 'full_name_required' using errcode = '22023';
  end if;
  if v_id_number is null then
    raise exception 'id_number_required' using errcode = '22023';
  end if;

  -- An ID number already on someone else's record is never taken over: linking it
  -- would show this account that person's passes. Reception resolves it.
  if exists (
    select 1 from public.people
    where id_number = v_id_number and profile_id is distinct from v_uid
  ) then
    raise exception 'id_number_in_use' using errcode = 'P0001';
  end if;

  insert into public.people (profile_id, full_name, id_number, email)
  values (v_uid, v_name, v_id_number, v_profile.email)
  on conflict (profile_id) do update
    set full_name = excluded.full_name,
        id_number = excluded.id_number,
        email = excluded.email
  returning id into v_person_id;

  update public.profiles set full_name = v_name where id = v_uid;

  v_vehicle_id := private.upsert_vehicle(v_person_id, p_plate);

  select * into v_pass
  from public.passes
  where person_id = v_person_id and type = 'staff'
  order by created_at desc
  limit 1
  for update;

  if found and v_pass.status = 'revoked' then
    raise exception 'pass_revoked' using errcode = 'P0001';
  end if;

  if found and v_pass.status = 'approved' and v_pass.valid_until > now() then
    update public.passes set vehicle_id = v_vehicle_id where id = v_pass.id
    returning * into v_pass;
  else
    select staff_pass_days into v_staff_days from public.settings;
    insert into public.passes (person_id, vehicle_id, type, status, valid_from, valid_until, source, decided_at)
    values (v_person_id, v_vehicle_id, 'staff', 'approved', now(),
            now() + make_interval(days => v_staff_days), 'web', now())
    returning * into v_pass;
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'pass_id', v_pass.id,
    'qr_token', v_pass.qr_token,
    'status', v_pass.status,
    'valid_from', v_pass.valid_from,
    'valid_until', v_pass.valid_until,
    'plate', private.normalize_plate(p_plate)
  ));
end;
$$;
