-- create_gate_request: guards register visitors without email as pending day or week
-- requests; returning visitors match on ID number; offline retries are idempotent.
begin;
\ir helpers/setup.psql
select plan(19);

select tests.build_world();
select tests.remember('req_id', gen_random_uuid());

-- ---------------------------------------------------------------------------
-- New visitor, day pass for today
-- ---------------------------------------------------------------------------
select tests.authenticate_as('guard');
select tests.remember('day_req', (public.create_gate_request(
  'Mphatso Kalua', 'mw 5555', 'day', 'Finance office', 'meeting', '+265 999 000 111', 'bt 12', null, tests.id('req_id')
) ->> 'pass_id')::uuid);
reset role;

select row_eq(
  format('select type, status, source, requested_by, host_name, purpose from public.passes where id = %L', tests.id('day_req')),
  row('day'::public.pass_type, 'pending'::public.pass_status, 'gate'::public.request_source, tests.id('guard'),
      'Finance office'::text, 'meeting'::text),
  'pending gate request created by the guard');
select row_eq(
  format('select valid_from, valid_until from public.passes where id = %L', tests.id('day_req')),
  row(private.local_midnight(private.local_today()), private.local_midnight(private.local_today() + 1)),
  'day pass runs from local midnight to the end of that day (Africa/Blantyre)');
select row_eq(
  format('select pe.full_name, pe.id_number, pe.phone, v.plate from public.passes p
          join public.people pe on pe.id = p.person_id join public.vehicles v on v.id = p.vehicle_id where p.id = %L',
         tests.id('day_req')),
  row('Mphatso Kalua'::text, 'MW5555'::text, '+265 999 000 111'::text, 'BT12'::text),
  'person and vehicle saved, ID number and plate normalised');

-- Offline retry with the same request id
select tests.authenticate_as('guard');
select is(tests.pick(public.create_gate_request('Mphatso Kalua', 'MW5555', 'day', 'Finance office', 'meeting',
                                                null, null, null, tests.id('req_id')), array['pass_id', 'replayed']),
          jsonb_build_object('pass_id', tests.id('day_req'), 'replayed', true),
          'retrying with the same client_request_id returns the original request');
reset role;
select is((select count(*)::int from public.passes where person_id = (select person_id from public.passes where id = tests.id('day_req'))),
          1, 'no duplicate request');

-- ---------------------------------------------------------------------------
-- Returning visitor, week pass starting later
-- ---------------------------------------------------------------------------
select tests.authenticate_as('guard');
select tests.remember('week_req', (public.create_gate_request(
  'M. Kalua', 'MW 5555', 'week', 'ICT', 'contractor', '+265 888 222 333', null, private.local_today() + 3
) ->> 'pass_id')::uuid);
reset role;
select is((select person_id from public.passes where id = tests.id('week_req')),
          (select person_id from public.passes where id = tests.id('day_req')),
          'returning visitor matched on ID number');
select row_eq(
  format('select pe.full_name, pe.phone from public.passes p join public.people pe on pe.id = p.person_id where p.id = %L',
         tests.id('week_req')),
  row('Mphatso Kalua'::text, '+265 888 222 333'::text),
  'existing name kept, phone updated');
select row_eq(
  format('select valid_from, valid_until from public.passes where id = %L', tests.id('week_req')),
  row(private.local_midnight(private.local_today() + 3), private.local_midnight(private.local_today() + 3) + interval '7 days'),
  'week pass runs 7 days (week_pass_days) from its start date');

-- The guard can attach an ID photo to their own request (Phase 1 policy).
select tests.authenticate_as('guard');
select lives_ok(format($$insert into public.id_photos (pass_id, storage_path) values (%L, %L)$$,
                       tests.id('week_req'), tests.id('week_req') || '/id.jpg'),
                'guard attaches an ID photo to the new request');

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------
select throws_ok($$select public.create_gate_request('A', 'B', 'staff', 'H', 'P')$$, '22023',
                 'pass_type_must_be_day_or_week', 'staff passes cannot be requested at the gate');
select throws_ok(format($$select public.create_gate_request('A', 'B', 'day', 'H', 'P', null, null, %L)$$, private.local_today() - 1),
                 '22023', 'start_date_out_of_range', 'start date cannot be in the past');
select throws_ok(format($$select public.create_gate_request('A', 'B', 'day', 'H', 'P', null, null, %L)$$, private.local_today() + 15),
                 '22023', 'start_date_out_of_range', 'start date at most 14 days ahead');
select lives_ok(format($$select public.create_gate_request('A', 'B', 'day', 'H', 'P', null, null, %L)$$, private.local_today() + 14),
                '14 days ahead is allowed');
select throws_ok($$select public.create_gate_request(' ', 'B', 'day', 'H', 'P')$$, '22023', 'full_name_required', 'name required');
select throws_ok($$select public.create_gate_request('A', ' ', 'day', 'H', 'P')$$, '22023', 'id_number_required', 'ID number required');
select throws_ok($$select public.create_gate_request('A', 'B', 'day', ' ', 'P')$$, '22023', 'host_name_required', 'who they visit required');
select throws_ok($$select public.create_gate_request('A', 'B', 'day', 'H', 'P', null, 'B-1!')$$, '22023', 'invalid_plate', 'bad plate refused');
reset role;

-- ---------------------------------------------------------------------------
-- Callers
-- ---------------------------------------------------------------------------
select tests.authenticate_as('staff');
select throws_ok($$select public.create_gate_request('A', 'B', 'day', 'H', 'P')$$, '42501', 'not_authorized',
                 'staff cannot create gate requests');
reset role;
select tests.authenticate_anon();
select throws_ok($$select public.create_gate_request('A', 'B', 'day', 'H', 'P')$$, '42501', null,
                 'anon cannot call create_gate_request');
reset role;

select * from finish();
rollback;
