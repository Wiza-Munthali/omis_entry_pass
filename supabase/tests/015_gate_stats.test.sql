-- gate_stats: counts for the gate app home screen, operators only.
begin;
\ir helpers/setup.psql
select plan(7);

select tests.build_world();
-- An entry from yesterday (Blantyre time) that must not count as today.
insert into public.visits (pass_id, person_id, gate_id, entry_at, exit_at)
values (tests.id('other_pass'), tests.id('other_person'), tests.id('main_gate'),
        private.local_midnight(private.local_today()) - interval '2 hours',
        private.local_midnight(private.local_today()) - interval '1 hour');

create temp table expected as select
  (select count(*) from public.visits where exit_at is null)::int as on_site,
  (select count(*) from public.visits where entry_at >= private.local_midnight(private.local_today()))::int as today,
  (select count(*) from public.visits where entry_at >= private.local_midnight(private.local_today())
     and gate_id = tests.id('main_gate'))::int as at_gate;
grant select on expected to authenticated;

select tests.authenticate_as('guard');
select is((public.gate_stats() ->> 'on_site')::int, (select on_site from expected), 'on site = open visits');
select is((public.gate_stats() ->> 'entries_today')::int, (select today from expected),
          'entries today counts from midnight in Africa/Blantyre');
select is((public.gate_stats(tests.id('main_gate')) ->> 'entries_today_at_gate')::int, (select at_gate from expected),
          'entries today at the chosen gate');
select ok(not (public.gate_stats() ? 'visits'), 'counts only, no rows');
reset role;

select tests.authenticate_as('receptionist');
select ok(public.gate_stats() ? 'on_site', 'receptionists see the counts');
reset role;
select tests.authenticate_as('staff');
select throws_ok('select public.gate_stats()', '42501', 'not_authorized', 'staff cannot');
reset role;
select tests.authenticate_anon();
select throws_ok('select public.gate_stats()', '42501', null, 'anon cannot');
reset role;

select * from finish();
rollback;
