-- people, vehicles, passes.
-- Spec: staff read their own; guards read only through the scan RPC and the on-site
-- view; receptionists and admins read all. No client writes: changes go through RPCs
-- and Edge Functions (standing rule; admin revoke/extend become RPCs).
begin;
\ir helpers/setup.psql
select plan(31);

select tests.build_world();
select tests.snapshot_counts();

-- ---------------------------------------------------------------------------
-- Staff: own rows only
-- ---------------------------------------------------------------------------
select tests.authenticate_as('staff');
select results_eq('select id from public.people', array[tests.id('staff_person')], 'staff reads own person row');
select results_eq('select id from public.vehicles', array[tests.id('staff_car')], 'staff reads own vehicles');
select results_eq('select id from public.passes', array[tests.id('staff_pass')], 'staff reads own pass');
reset role;

select tests.authenticate_as('other_staff');
select results_eq('select id from public.passes', array[tests.id('other_pass')], 'other staff reads only their pass');
select is((select count(*)::int from public.vehicles), 0, 'other staff sees no vehicles (has none)');
reset role;

-- ---------------------------------------------------------------------------
-- Guard: no direct reads
-- ---------------------------------------------------------------------------
select tests.authenticate_as('guard');
select is((select count(*)::int from public.people), 0, 'guard reads no people');
select is((select count(*)::int from public.vehicles), 0, 'guard reads no vehicles');
select is((select count(*)::int from public.passes), 0, 'guard reads no passes');
reset role;

-- ---------------------------------------------------------------------------
-- Receptionist and admin: everything
-- ---------------------------------------------------------------------------
select tests.authenticate_as('receptionist');
select is((select count(*)::int from public.people), tests.total('people'), 'receptionist reads all people');
select is((select count(*)::int from public.vehicles), tests.total('vehicles'), 'receptionist reads all vehicles');
select is((select count(*)::int from public.passes), tests.total('passes'), 'receptionist reads all passes');
reset role;

select tests.authenticate_as('admin');
select is((select count(*)::int from public.people), tests.total('people'), 'admin reads all people');
select is((select count(*)::int from public.vehicles), tests.total('vehicles'), 'admin reads all vehicles');
select is((select count(*)::int from public.passes), tests.total('passes'), 'admin reads all passes');
reset role;

-- A deactivated operator is treated as nobody.
select tests.authenticate_as('inactive_admin');
select is((select count(*)::int from public.passes), 0, 'deactivated admin reads no passes');
reset role;

-- ---------------------------------------------------------------------------
-- Anonymous: nothing
-- ---------------------------------------------------------------------------
select tests.authenticate_anon();
select throws_ok('select * from public.people', '42501', null, 'anon cannot read people');
select throws_ok('select * from public.vehicles', '42501', null, 'anon cannot read vehicles');
select throws_ok('select * from public.passes', '42501', null, 'anon cannot read passes');
reset role;

-- ---------------------------------------------------------------------------
-- No direct writes for anyone, admins included
-- ---------------------------------------------------------------------------
create function pg_temp.write_attempts(p_key text) returns setof text language plpgsql as $$
begin
  perform tests.authenticate_as(p_key);
  return next throws_ok(
    $q$insert into public.passes (person_id, type, status, valid_from, valid_until)
       values (tests.id('staff_person'), 'staff', 'approved', now(), now() + interval '1 year')$q$,
    '42501', null, p_key || ' cannot insert passes');
  return next throws_ok(
    $q$update public.passes set status = 'approved' where id = tests.id('web_pending')$q$,
    '42501', null, p_key || ' cannot update passes');
  reset role;
end;
$$;

select * from pg_temp.write_attempts('staff');
select * from pg_temp.write_attempts('guard');
select * from pg_temp.write_attempts('receptionist');
select * from pg_temp.write_attempts('admin');

select tests.authenticate_as('admin');
select throws_ok($$delete from public.passes where id = tests.id('web_pending')$$,
                 '42501', null, 'admin cannot delete passes');
select throws_ok($$insert into public.people (full_name) values ('X')$$,
                 '42501', null, 'admin cannot insert people');
reset role;
select tests.authenticate_as('staff');
select throws_ok($$update public.people set id_number = 'X' where id = tests.id('staff_person')$$,
                 '42501', null, 'staff cannot edit own person row directly');
select throws_ok($$insert into public.vehicles (person_id, plate) values (tests.id('staff_person'), 'AB1')$$,
                 '42501', null, 'staff cannot add vehicles directly');
reset role;

select is((select status::text from public.passes where id = tests.id('web_pending')), 'pending', 'pending pass unchanged');

select * from finish();
rollback;
