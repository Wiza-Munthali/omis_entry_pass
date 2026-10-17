-- gates, settings, flags.
-- Spec: admins write; operators read gates and the settings they need; flags are the
-- admin review queue.
begin;
\ir helpers/setup.psql
select plan(27);

select tests.build_world();
select tests.snapshot_counts();

-- ---------------------------------------------------------------------------
-- gates
-- ---------------------------------------------------------------------------
select tests.authenticate_as('guard');
select is((select count(*)::int from public.gates), tests.total('gates'), 'guard reads all gates (to pick one)');
select throws_ok($$insert into public.gates (name) values ('Guard gate')$$, '42501', null, 'guard cannot add gates');
with u as (update public.gates set is_active = false returning 1)
select is(count(*)::int, 0, 'guard cannot deactivate gates') from u;
reset role;

select tests.authenticate_as('receptionist');
select is((select count(*)::int from public.gates), tests.total('gates'), 'receptionist reads gates');
select throws_ok($$insert into public.gates (name) values ('Rec gate')$$, '42501', null, 'receptionist cannot add gates');
with u as (delete from public.gates where id = tests.id('main_gate') returning 1)
select is(count(*)::int, 0, 'receptionist cannot delete gates') from u;
reset role;

select tests.authenticate_as('staff');
select is((select count(*)::int from public.gates), 0, 'staff read no gates');
reset role;
select tests.authenticate_anon();
select throws_ok('select * from public.gates', '42501', null, 'anon cannot read gates');
reset role;

select tests.authenticate_as('admin');
select lives_ok($$insert into public.gates (name) values ('North gate')$$, 'admin adds a gate');
select lives_ok($$update public.gates set is_active = false where name = 'North gate'$$, 'admin deactivates a gate');
select lives_ok($$delete from public.gates where name = 'North gate'$$, 'admin deletes an unused gate');
reset role;

-- ---------------------------------------------------------------------------
-- settings
-- ---------------------------------------------------------------------------
select tests.authenticate_as('guard');
select is((select approval_timeout_minutes from public.settings), 5, 'guard reads settings');
with u as (update public.settings set approval_timeout_minutes = 60 returning 1)
select is(count(*)::int, 0, 'guard cannot change settings') from u;
reset role;

select tests.authenticate_as('receptionist');
with u as (update public.settings set allowed_email_domains = array['evil.com'] returning 1)
select is(count(*)::int, 0, 'receptionist cannot change settings') from u;
reset role;

select tests.authenticate_as('staff');
select is((select count(*)::int from public.settings), 0, 'staff cannot read settings');
reset role;
select tests.authenticate_anon();
select throws_ok('select * from public.settings', '42501', null, 'anon cannot read settings');
reset role;

select tests.authenticate_as('admin');
select lives_ok($$update public.settings set approval_timeout_minutes = 10, allowed_email_domains = array['ghii.test', 'ghii.org']$$,
                'admin updates settings');
select throws_ok($$insert into public.settings (id) values (true)$$, '42501', null, 'admin cannot insert a settings row');
select throws_ok($$delete from public.settings$$, '42501', null, 'admin cannot delete settings');
select throws_ok($$update public.settings set approval_timeout_minutes = 0$$, '23514', null, 'settings values are validated');
reset role;
select is((select approval_timeout_minutes from public.settings), 10, 'admin settings change applied');

-- ---------------------------------------------------------------------------
-- flags
-- ---------------------------------------------------------------------------
select tests.authenticate_as('guard');
select is((select count(*)::int from public.flags), 0, 'guard reads no flags');
reset role;
select tests.authenticate_as('receptionist');
select is((select count(*)::int from public.flags), 0, 'receptionist reads no flags');
with u as (update public.flags set resolved_at = now() returning 1)
select is(count(*)::int, 0, 'receptionist cannot resolve flags') from u;
reset role;

select tests.authenticate_as('admin');
select is((select count(*)::int from public.flags), tests.total('flags'), 'admin reads all flags');
select lives_ok($$update public.flags set resolved_by = auth.uid(), resolved_at = now() where id = tests.id('flag_open')$$,
                'admin resolves a flag');
select throws_ok($$insert into public.flags (type) values ('double_entry')$$, '42501', null,
                 'flags are raised by the system, not inserted by clients');
reset role;

select * from finish();
rollback;
