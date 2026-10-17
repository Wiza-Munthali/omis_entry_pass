-- Schema-wide guarantees: RLS everywhere, no anon access, no client writes to
-- business tables, and the core constraints.
begin;
\ir helpers/setup.psql
select plan(38);

-- RLS is enabled on every table in public (catches tables added later without it).
select is(
  array(select c.relname::text from pg_class c join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity order by 1),
  '{}'::text[],
  'every public table has RLS enabled'
);

-- anon has no privilege on any table or view in public.
select is(
  array(select c.relname::text from pg_class c join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relkind in ('r', 'v')
          and (has_table_privilege('anon', c.oid, 'select')
               or has_table_privilege('anon', c.oid, 'insert')
               or has_table_privilege('anon', c.oid, 'update')
               or has_table_privilege('anon', c.oid, 'delete'))
        order by 1),
  '{}'::text[],
  'anon has no table privileges in public'
);

-- Clients never write people, vehicles, passes, visits or audit_log directly.
select ok(not has_table_privilege('authenticated', 'public.' || t, p), format('authenticated cannot %s %s', p, t))
from unnest(array['people', 'vehicles', 'passes', 'visits', 'audit_log']) t,
     unnest(array['insert', 'update', 'delete']) p;

-- profiles.email and profiles.id are never client-writable.
select ok(not has_column_privilege('authenticated', 'public.profiles', 'email', 'update'), 'profiles.email not client-updatable');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'id', 'update'), 'profiles.id not client-updatable');

-- Tables created by later migrations start with no client grants.
create table public.zz_future (id int);
select ok(not has_table_privilege('anon', 'public.zz_future', 'select')
          and not has_table_privilege('authenticated', 'public.zz_future', 'select'),
          'new tables get no default grants');

-- Enums match the spec.
select enum_has_labels('public', 'user_role', array['admin', 'receptionist', 'guard', 'staff']);
select enum_has_labels('public', 'pass_type', array['staff', 'day', 'week']);
select enum_has_labels('public', 'pass_status', array['pending', 'approved', 'rejected', 'revoked', 'expired']);
select enum_has_labels('public', 'request_source', array['web', 'gate']);
select enum_has_labels('public', 'flag_type', array['exit_without_entry', 'double_entry', 'auto_closed',
                                                     'scan_invalid_pass', 'approval_escalated', 'offline_conflict']);

-- Settings: exactly one row with the spec defaults.
select is((select count(*)::int from public.settings), 1, 'settings has one row');
select throws_ok('insert into public.settings (id) values (false)', '23514', null, 'a second settings row is rejected');
select row_eq(
  'select approval_timeout_minutes, auto_close_time, id_photo_retention_days, staff_pass_days, week_pass_days from public.settings',
  row(5, '23:59'::time, 30, 365, 7),
  'settings defaults match the spec'
);

select tests.build_world();

-- Tokens: 32 random bytes as base64url (43 chars), unique per pass.
select ok((select bool_and(qr_token ~ '^[A-Za-z0-9_-]{43}$') from public.passes), 'qr_token is 43-char base64url');
select ok((select bool_and(status_token ~ '^[A-Za-z0-9_-]{32}$') from public.passes), 'status_token is 32-char base64url');
select throws_ok(
  format('update public.passes set qr_token = (select qr_token from public.passes where id = %L) where id = %L',
         tests.id('staff_pass'), tests.id('other_pass')),
  '23505', null, 'qr_token is unique');

-- Plates are stored uppercase without spaces.
select is((select plate from public.vehicles where id = tests.id('staff_car')), 'TT1001', 'vehicle plate normalised');
select throws_ok(
  format('insert into public.vehicles (person_id, plate) values (%L, %L)', tests.id('visitor2'), 'AB-12'),
  '23514', null, 'plates with symbols are rejected');

-- At most one open visit per pass.
select throws_ok(
  format('insert into public.visits (pass_id, person_id, gate_id, entry_at) values (%L, %L, %L, now())',
         tests.id('decided_by_rec'), tests.id('visitor'), tests.id('main_gate')),
  '23505', null, 'second open visit for the same pass is rejected');
select throws_ok(
  format('update public.visits set exit_at = entry_at - interval ''1 minute'' where id = %L', tests.id('open_visit')),
  '23514', null, 'exit before entry is rejected');

-- Rejected passes carry a reason; validity window is ordered.
select throws_ok(
  format('update public.passes set status = ''rejected'' where id = %L', tests.id('web_pending')),
  '23514', null, 'rejecting without a reason is rejected');
select throws_ok(
  format('update public.passes set valid_until = valid_from where id = %L', tests.id('web_pending')),
  '23514', null, 'valid_until must be after valid_from');

-- ID photos get delete_after from settings.id_photo_retention_days.
select ok(
  (select delete_after between now() + interval '29 days 23 hours' and now() + interval '30 days 1 hour'
   from public.id_photos where id = tests.id('photo_pending')),
  'id_photos.delete_after = now + 30 days');

select * from finish();
rollback;
