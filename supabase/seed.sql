-- Local development seed, applied by `npm run db:reset`.
-- Never run against production.
--
-- Accounts sign in with an email code; codes land in Mailpit (http://127.0.0.1:54324).
--   admin@ghii.test         Tadala Nkhoma    admin
--   reception@ghii.test     Mercy Banda      receptionist
--   guard@ghii.test         Yamikani Phiri   guard
--   chikondi@ghii.test      Chikondi Banda   staff, approved pass, car BT 4521
--   grace@ghii.test         Grace Chirwa     staff, revoked pass
--
-- Visitors (no accounts):
--   Kondwani Mwale   week pass, approved (gate request), on site now at Main gate
--   Thoko Phiri      day pass, pending (web request)
--   Chisomo Gondwe   day pass, rejected
--   Limbani Kamanga  day pass from last week, expired

update public.settings
set org_name = 'GHII',
    allowed_email_domains = array['ghii.test'];

-- ---------------------------------------------------------------------------
-- Auth users (profiles are created by the on_auth_user_created trigger; the role
-- comes from app_metadata)
-- ---------------------------------------------------------------------------
create function pg_temp.seed_user(p_id uuid, p_email text, p_name text, p_role text)
returns void
language sql
as $$
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    email_change_token_current, phone_change, phone_change_token, reauthentication_token
  ) values (
    '00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated',
    p_email, '', now(),
    jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email'), 'role', p_role),
    jsonb_build_object('full_name', p_name),
    now(), now(), '', '', '', '', '', '', '', ''
  );

  insert into auth.identities (user_id, provider_id, provider, identity_data, created_at, updated_at)
  values (
    p_id, p_id::text, 'email',
    jsonb_build_object('sub', p_id::text, 'email', p_email, 'email_verified', true),
    now(), now()
  );
$$;

select pg_temp.seed_user('00000000-0000-4000-8000-00000000a001', 'admin@ghii.test', 'Tadala Nkhoma', 'admin');
select pg_temp.seed_user('00000000-0000-4000-8000-00000000a002', 'reception@ghii.test', 'Mercy Banda', 'receptionist');
select pg_temp.seed_user('00000000-0000-4000-8000-00000000a003', 'guard@ghii.test', 'Yamikani Phiri', 'guard');
select pg_temp.seed_user('00000000-0000-4000-8000-00000000a004', 'chikondi@ghii.test', 'Chikondi Banda', 'staff');
select pg_temp.seed_user('00000000-0000-4000-8000-00000000a005', 'grace@ghii.test', 'Grace Chirwa', 'staff');

-- ---------------------------------------------------------------------------
-- Gates, people, passes, visits
-- ---------------------------------------------------------------------------
do $$
declare
  admin_id constant uuid := '00000000-0000-4000-8000-00000000a001';
  reception_id constant uuid := '00000000-0000-4000-8000-00000000a002';
  guard_id constant uuid := '00000000-0000-4000-8000-00000000a003';
  -- Start of today in Africa/Blantyre, as a UTC timestamptz.
  today constant timestamptz :=
    date_trunc('day', now() at time zone 'Africa/Blantyre') at time zone 'Africa/Blantyre';
  main_gate uuid;
  back_gate uuid;
  person uuid;
  vehicle uuid;
  pass uuid;
begin
  insert into public.gates (name) values ('Main gate') returning id into main_gate;
  insert into public.gates (name) values ('Back gate') returning id into back_gate;

  -- Chikondi Banda: staff, approved, drives BT 4521; came and left yesterday.
  insert into public.people (profile_id, full_name, id_number, phone, email)
  values ('00000000-0000-4000-8000-00000000a004', 'Chikondi Banda', 'MW-STF-1001', '+265 991 234 567', 'chikondi@ghii.test')
  returning id into person;
  insert into public.vehicles (person_id, plate, description)
  values (person, 'BT 4521', 'White Toyota Corolla')
  returning id into vehicle;
  insert into public.passes (person_id, vehicle_id, type, status, valid_from, valid_until, source, decided_at)
  values (person, vehicle, 'staff', 'approved', today - interval '30 days', today + interval '335 days', 'web', today - interval '30 days')
  returning id into pass;
  insert into public.visits (pass_id, person_id, gate_id, vehicle_plate, entry_at, entry_by, exit_at, exit_by)
  values (pass, person, main_gate, 'BT4521',
          today - interval '1 day' + interval '7 hours 52 minutes', guard_id,
          today - interval '1 day' + interval '17 hours 5 minutes', guard_id);

  -- Grace Chirwa: staff pass revoked by the admin.
  insert into public.people (profile_id, full_name, id_number, phone, email)
  values ('00000000-0000-4000-8000-00000000a005', 'Grace Chirwa', 'MW-STF-1002', '+265 888 456 789', 'grace@ghii.test')
  returning id into person;
  insert into public.passes (person_id, type, status, valid_from, valid_until, source, decided_by, decided_at)
  values (person, 'staff', 'revoked', today - interval '200 days', today + interval '165 days', 'web', admin_id, today - interval '2 days');

  -- Kondwani Mwale: week pass from a gate request, approved by reception, on site now.
  insert into public.people (full_name, id_number, phone)
  values ('Kondwani Mwale', 'MW-ID-7731', '+265 995 112 233')
  returning id into person;
  insert into public.vehicles (person_id, plate, description)
  values (person, 'MZ 2210', 'Blue Nissan pickup')
  returning id into vehicle;
  insert into public.passes (person_id, vehicle_id, type, status, valid_from, valid_until,
                             host_name, purpose, source, requested_by, decided_by, decided_at)
  values (person, vehicle, 'week', 'approved', today - interval '2 days', today + interval '5 days',
          'ICT unit', 'contractor', 'gate', guard_id, reception_id, today - interval '2 days' + interval '8 hours')
  returning id into pass;
  insert into public.visits (pass_id, person_id, gate_id, vehicle_plate, entry_at, entry_by)
  values (pass, person, main_gate, 'MZ2210', today + interval '8 hours 14 minutes', guard_id);

  -- Thoko Phiri: day pass requested on the web, waiting for approval.
  insert into public.people (full_name, id_number, phone, email)
  values ('Thoko Phiri', 'MW-ID-4410', '+265 884 765 432', 'thoko.phiri@example.com')
  returning id into person;
  insert into public.passes (person_id, type, status, valid_from, valid_until, host_name, purpose, source)
  values (person, 'day', 'pending', today, today + interval '1 day', 'Finance office', 'meeting', 'web');

  -- Chisomo Gondwe: day pass rejected.
  insert into public.people (full_name, id_number, phone, email)
  values ('Chisomo Gondwe', 'MW-ID-5521', '+265 993 210 987', 'chisomo.g@example.com')
  returning id into person;
  insert into public.passes (person_id, type, status, valid_from, valid_until, host_name, purpose, source,
                             decided_by, decided_at, reject_reason)
  values (person, 'day', 'rejected', today, today + interval '1 day', 'Director''s office', 'interview', 'web',
          reception_id, today + interval '7 hours 40 minutes', 'Host is away today');

  -- Limbani Kamanga: day pass from last week, now expired; visited and left.
  insert into public.people (full_name, id_number, phone)
  values ('Limbani Kamanga', 'MW-ID-6604', '+265 999 876 543')
  returning id into person;
  insert into public.passes (person_id, type, status, valid_from, valid_until, host_name, purpose, source,
                             requested_by, decided_by, decided_at)
  values (person, 'day', 'expired', today - interval '7 days', today - interval '6 days', 'Stores', 'delivery', 'gate',
          guard_id, reception_id, today - interval '7 days' + interval '9 hours')
  returning id into pass;
  insert into public.visits (pass_id, person_id, gate_id, entry_at, entry_by, exit_at, exit_by)
  values (pass, person, back_gate,
          today - interval '7 days' + interval '9 hours 10 minutes', guard_id,
          today - interval '7 days' + interval '9 hours 55 minutes', guard_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Vault entries the database uses to call Edge Functions (decision emails).
-- Local values only: the Kong gateway inside the Supabase Docker network and a
-- dev-only shared secret matching supabase/functions/.env(.example).
-- In a hosted project, create both with real values (see README).
-- ---------------------------------------------------------------------------
select vault.create_secret('http://supabase_kong_omis-entry:8000/functions/v1', 'functions_url');
select vault.create_secret('local-dev-only-internal-secret', 'internal_hook_secret');
