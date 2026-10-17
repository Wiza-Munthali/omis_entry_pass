-- check_out: manual check-out from the on-site list (guard and above), idempotent on
-- client_event_id.
begin;
\ir helpers/setup.psql
select plan(10);

select tests.build_world();
select tests.remember('ev_out', gen_random_uuid());

select tests.authenticate_as('guard');
select is(
  tests.pick(public.check_out(tests.id('open_visit'), tests.id('ev_out')), array['result', 'full_name', 'visit_id']),
  jsonb_build_object('result', 'exit_recorded', 'full_name', 'Visitor One', 'visit_id', tests.id('open_visit')),
  'guard checks out an open visit');
reset role;
select ok((select exit_at is not null and exit_by = tests.id('guard') and client_exit_id = tests.id('ev_out')
           from public.visits where id = tests.id('open_visit')),
          'visit closed by the guard with the event id');

select tests.authenticate_as('guard');
select is(tests.pick(public.check_out(tests.id('open_visit'), tests.id('ev_out')), array['result', 'replayed']),
          '{"result": "exit_recorded", "replayed": true}', 'retrying the same event returns the original result');
select is(public.check_out(tests.id('open_visit'), gen_random_uuid()) ->> 'result', 'already_checked_out',
          'a second check-out reports already_checked_out');
select is(public.check_out(tests.id('closed_visit')) ->> 'result', 'already_checked_out',
          'checking out a closed visit changes nothing');
select throws_ok(format('select public.check_out(%L)', gen_random_uuid()), '22023', 'visit_not_found',
                 'unknown visit is refused');
reset role;
select is((select exit_by from public.visits where id = tests.id('closed_visit')), tests.id('guard'),
          'closed visit unchanged');

select tests.authenticate_as('staff');
select throws_ok(format('select public.check_out(%L)', tests.id('open_visit')), '42501', 'not_authorized',
                 'staff cannot check people out');
reset role;
select tests.authenticate_as('inactive_admin');
select throws_ok(format('select public.check_out(%L)', tests.id('open_visit')), '42501', 'not_authorized',
                 'deactivated operators cannot check people out');
reset role;
select tests.authenticate_anon();
select throws_ok(format('select public.check_out(%L)', tests.id('open_visit')), '42501', null,
                 'anon cannot call check_out');
reset role;

select * from finish();
rollback;
