-- audit_log: written by triggers (and later RPCs), readable by admins only, never
-- writable by clients, and free of personal data and secret tokens.
begin;
\ir helpers/setup.psql
select plan(14);

select tests.build_world();

-- ---------------------------------------------------------------------------
-- Access
-- ---------------------------------------------------------------------------
select tests.snapshot_counts();
select tests.authenticate_as('admin');
select is((select count(*)::int from public.audit_log), tests.total('audit_log'), 'admin reads the audit log');
select throws_ok($$insert into public.audit_log (action, target_table) values ('x', 'y')$$, '42501', null, 'admin cannot write audit entries');
select throws_ok($$delete from public.audit_log$$, '42501', null, 'admin cannot delete audit entries');
select throws_ok($$update public.audit_log set action = 'x'$$, '42501', null, 'admin cannot edit audit entries');
reset role;

select tests.authenticate_as('receptionist');
select is((select count(*)::int from public.audit_log), 0, 'receptionist reads no audit entries');
reset role;
select tests.authenticate_as('guard');
select is((select count(*)::int from public.audit_log), 0, 'guard reads no audit entries');
reset role;
select tests.authenticate_anon();
select throws_ok('select * from public.audit_log', '42501', null, 'anon cannot read audit log');
reset role;

-- ---------------------------------------------------------------------------
-- What gets recorded
-- ---------------------------------------------------------------------------

-- An admin action through the API is attributed to the admin.
select tests.authenticate_as('admin');
update public.profiles set role = 'receptionist' where id = tests.id('guard2');
reset role;
select row_eq(
  format($$select actor_id, action, details #> '{changed,role}' from public.audit_log
           where target_table = 'profiles' and target_id = %L order by id desc limit 1$$, tests.id('guard2')),
  row(tests.id('admin'), 'update'::text, '{"old": "guard", "new": "receptionist"}'::jsonb),
  'role change logged with actor, old and new value');

-- Status changes keep old and new values.
update public.passes set status = 'approved', decided_at = now() where id = tests.id('web_pending');
select is(
  (select details #> '{changed,status}' from public.audit_log
   where target_table = 'passes' and target_id = tests.id('web_pending')::text order by id desc limit 1),
  '{"old": "pending", "new": "approved"}'::jsonb,
  'pass status change logged');

-- Personal fields are marked as changed but their values are not copied.
update public.people set full_name = 'Visitor Renamed', id_number = 'T-NEW' where id = tests.id('visitor');
select is(
  (select details -> 'changed' from public.audit_log
   where target_table = 'people' and target_id = tests.id('visitor')::text order by id desc limit 1),
  '{"full_name": "redacted", "id_number": "redacted"}'::jsonb,
  'personal fields are redacted in updates');
select ok(
  not exists (select 1 from public.audit_log where details::text like '%Visitor One%' or details::text like '%T-VIS-1%'),
  'no names or ID numbers in the audit log');

-- Secrets never reach the log.
select ok(
  not exists (select 1 from public.audit_log a join public.passes p
              on a.details::text like '%' || p.qr_token || '%' or a.details::text like '%' || p.status_token || '%'),
  'no QR or status tokens in the audit log');
select ok(
  (select details -> 'row' ? 'type' and not (details -> 'row' ? 'qr_token')
   from public.audit_log where action = 'insert' and target_table = 'passes'
     and target_id = tests.id('staff_pass')::text),
  'pass inserts keep non-personal fields only');

-- No-op updates are not logged.
select tests.snapshot_counts();
update public.gates set name = name where id = tests.id('main_gate');
select is((select count(*)::int from public.audit_log), tests.total('audit_log'), 'no-op update writes nothing');

select * from finish();
rollback;
