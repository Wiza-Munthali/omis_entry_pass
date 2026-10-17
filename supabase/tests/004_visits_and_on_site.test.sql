-- visits and the on_site view.
-- Spec: guards read open visits at any gate (on-site list); receptionists and admins
-- read all; no direct inserts or updates from any client, only through RPCs.
begin;
\ir helpers/setup.psql
select plan(21);

select tests.build_world();
select tests.snapshot_counts();

-- ---------------------------------------------------------------------------
-- visits SELECT
-- ---------------------------------------------------------------------------
select tests.authenticate_as('guard');
select ok(
  (select bool_and(exit_at is null) from public.visits) and
  (select count(*)::int from public.visits) = (select count(*)::int from public.visits where exit_at is null),
  'guard sees only open visits');
select ok(exists (select 1 from public.visits where id = tests.id('open_visit')), 'guard sees the open visit');
select ok(not exists (select 1 from public.visits where id = tests.id('closed_visit')), 'guard does not see closed visits');
reset role;

select tests.authenticate_as('receptionist');
select is((select count(*)::int from public.visits), tests.total('visits'), 'receptionist reads all visits');
reset role;
select tests.authenticate_as('admin');
select is((select count(*)::int from public.visits), tests.total('visits'), 'admin reads all visits');
reset role;
select tests.authenticate_as('staff');
select is((select count(*)::int from public.visits), 0, 'staff read no visits');
reset role;
select tests.authenticate_as('inactive_admin');
select is((select count(*)::int from public.visits), 0, 'deactivated operator reads no visits');
reset role;
select tests.authenticate_anon();
select throws_ok('select * from public.visits', '42501', null, 'anon cannot read visits');
reset role;

-- ---------------------------------------------------------------------------
-- visits: no client writes
-- ---------------------------------------------------------------------------
create function pg_temp.write_attempts(p_key text) returns setof text language plpgsql as $$
begin
  perform tests.authenticate_as(p_key);
  return next throws_ok(
    $q$insert into public.visits (pass_id, person_id, gate_id, entry_at)
       values (tests.id('other_pass'), tests.id('other_person'), tests.id('main_gate'), now())$q$,
    '42501', null, p_key || ' cannot insert visits');
  return next throws_ok(
    $q$update public.visits set exit_at = now() where id = tests.id('open_visit')$q$,
    '42501', null, p_key || ' cannot check out by updating visits');
  reset role;
end;
$$;
select * from pg_temp.write_attempts('guard');
select * from pg_temp.write_attempts('receptionist');
select * from pg_temp.write_attempts('admin');
select tests.authenticate_as('admin');
select throws_ok($$delete from public.visits where id = tests.id('closed_visit')$$, '42501', null, 'admin cannot delete visits');
reset role;
select ok((select exit_at is null from public.visits where id = tests.id('open_visit')), 'open visit unchanged');

-- ---------------------------------------------------------------------------
-- on_site view: operators see who is on site, with names; others see nothing
-- ---------------------------------------------------------------------------
select tests.authenticate_as('guard');
select ok(
  exists (select 1 from public.on_site
          where visit_id = tests.id('open_visit') and full_name = 'Visitor One'
            and pass_type = 'week' and gate_name = 'Test gate' and vehicle_plate = 'TT2002'),
  'guard sees on-site visitor with name, type, gate and plate');
select ok(not exists (select 1 from public.on_site where visit_id = tests.id('closed_visit')),
          'checked-out visits are not on site');
reset role;
select tests.authenticate_as('receptionist');
select ok(exists (select 1 from public.on_site where visit_id = tests.id('open_visit')), 'receptionist sees on-site list');
reset role;
select tests.authenticate_as('staff');
select is((select count(*)::int from public.on_site), 0, 'staff see nobody on site');
reset role;
select tests.authenticate_anon();
select throws_ok('select * from public.on_site', '42501', null, 'anon cannot read on_site');
reset role;

select * from finish();
rollback;
