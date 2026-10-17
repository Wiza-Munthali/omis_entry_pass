-- record_scan: every outcome from the spec (entry, exit, pending, rejected, revoked,
-- expired, invalid, duplicate event) plus not_yet_valid, offline timing and access.
begin;
\ir helpers/setup.psql
select plan(44);

select tests.build_world();

-- Extra passes in each blocked state (visitor2 holds them).
with r as (
  insert into public.passes (person_id, type, status, valid_from, valid_until, decided_at, reject_reason)
  values (tests.id('visitor2'), 'day', 'rejected', now() - interval '1 hour', now() + interval '1 day', now(), 'Host away')
  returning id
) insert into tests.ids select 'rejected_pass', id from r;
with r as (
  insert into public.passes (person_id, type, status, valid_from, valid_until)
  values (tests.id('visitor2'), 'week', 'revoked', now() - interval '1 day', now() + interval '6 days')
  returning id
) insert into tests.ids select 'revoked_pass', id from r;
with r as (
  insert into public.passes (person_id, type, status, valid_from, valid_until)
  values (tests.id('visitor2'), 'day', 'expired', now() - interval '3 days', now() - interval '2 days')
  returning id
) insert into tests.ids select 'expired_pass', id from r;
with r as (
  insert into public.passes (person_id, type, status, valid_from, valid_until)
  values (tests.id('visitor2'), 'day', 'approved', now() - interval '2 days', now() - interval '1 day')
  returning id
) insert into tests.ids select 'lapsed_pass', id from r;
with r as (
  insert into public.passes (person_id, type, status, valid_from, valid_until)
  values (tests.id('visitor2'), 'week', 'approved', now() + interval '1 day', now() + interval '8 days')
  returning id
) insert into tests.ids select 'future_pass', id from r;
with r as (insert into public.gates (name, is_active) values ('Closed gate', false) returning id)
insert into tests.ids select 'closed_gate', id from r;
select tests.remember('ev_entry', gen_random_uuid());
select tests.remember('ev_exit', gen_random_uuid());
select tests.remember('ev_blocked', gen_random_uuid());
select tests.remember('ev_invalid', gen_random_uuid());

-- ---------------------------------------------------------------------------
-- Entry and exit
-- ---------------------------------------------------------------------------
select tests.authenticate_as('guard');

select is(
  tests.pick(public.record_scan(tests.qr('staff_pass'), tests.id('main_gate'), null, tests.id('ev_entry')),
             array['result', 'full_name', 'pass_type', 'plate']),
  '{"result": "entry_recorded", "full_name": "Staff Person", "pass_type": "staff", "plate": "TT1001"}',
  'approved pass with no open visit → entry_recorded with name, type and plate from the pass');
reset role;
select row_eq(
  format('select gate_id, entry_by, vehicle_plate, exit_at, recorded_offline from public.visits where client_entry_id = %L',
         tests.id('ev_entry')),
  row(tests.id('main_gate'), tests.id('guard'), 'TT1001'::text, null::timestamptz, false),
  'entry creates an open visit at the gate, by the guard, with the plate');

select tests.authenticate_as('guard');
select is(
  tests.pick(public.record_scan(tests.qr('staff_pass'), tests.id('main_gate'), null, tests.id('ev_exit')),
             array['result', 'full_name']),
  '{"result": "exit_recorded", "full_name": "Staff Person"}',
  'second scan → exit_recorded');
reset role;
select ok(
  (select exit_at is not null and exit_by = tests.id('guard') and client_exit_id = tests.id('ev_exit')
   from public.visits where client_entry_id = tests.id('ev_entry')),
  'exit closes the same visit');

select tests.authenticate_as('guard');
select ok(
  (select (r ->> 'duration_seconds')::int >= 0 and r ? 'entry_at' and r ? 'exit_at'
   from (select public.record_scan(tests.qr('decided_by_rec'), tests.id('main_gate')) r) s),
  'exit response includes entry time, exit time and duration on site');
select is(public.record_scan(tests.qr('staff_pass'), tests.id('main_gate')) ->> 'result', 'entry_recorded',
          'third scan → a new entry');
reset role;
select is((select count(*)::int from public.visits where pass_id = tests.id('staff_pass') and exit_at is null), 1,
          'still only one open visit for the pass');

-- ---------------------------------------------------------------------------
-- Blocked passes: result, name, and a scan_invalid_pass flag; no visit
-- ---------------------------------------------------------------------------
create function pg_temp.blocked(p_pass text, p_expected text) returns setof text language plpgsql as $$
declare
  r jsonb;
  visits_before int;
  flags_before int;
begin
  select count(*) into visits_before from public.visits where pass_id = tests.id(p_pass);
  select count(*) into flags_before from public.flags where pass_id = tests.id(p_pass) and type = 'scan_invalid_pass'
    and details ->> 'result' = p_expected and details ->> 'scanned_by' = tests.id('guard')::text;
  perform tests.authenticate_as('guard');
  r := public.record_scan(tests.qr(p_pass), tests.id('main_gate'));
  reset role;
  return next is(r ->> 'result', p_expected, p_pass || ' → ' || p_expected);
  return next ok(r ? 'full_name', p_pass || ' response names the person');
  return next is((select count(*)::int from public.flags where pass_id = tests.id(p_pass) and type = 'scan_invalid_pass'
                    and details ->> 'result' = p_expected and details ->> 'scanned_by' = tests.id('guard')::text),
                 flags_before + 1, p_pass || ' raises a scan_invalid_pass flag');
  return next is((select count(*)::int from public.visits where pass_id = tests.id(p_pass)), visits_before,
                 p_pass || ' records no visit');
end;
$$;

select * from pg_temp.blocked('web_pending', 'pending');
select * from pg_temp.blocked('rejected_pass', 'rejected');
select * from pg_temp.blocked('revoked_pass', 'revoked');
select * from pg_temp.blocked('expired_pass', 'expired');
select is((select r ->> 'result' from (select tests.authenticate_as('guard'), public.record_scan(tests.qr('lapsed_pass'), tests.id('main_gate')) r) s),
          'expired', 'approved pass past valid_until → expired');
reset role;
select tests.authenticate_as('guard');
select is(public.record_scan(tests.qr('future_pass'), tests.id('main_gate')) ->> 'result', 'not_yet_valid',
          'approved pass before valid_from → not_yet_valid');

-- Unknown code: no name, nothing written.
select is(public.record_scan('no-such-token', tests.id('main_gate'), null, tests.id('ev_invalid')),
          '{"result": "invalid"}', 'unknown QR code → invalid with no details');
reset role;
select ok(not exists (select 1 from public.flags where details ->> 'client_event_id' = tests.id('ev_invalid')::text),
          'invalid scan writes no flag');

-- ---------------------------------------------------------------------------
-- Duplicate events (offline retries) return the original result without writing
-- ---------------------------------------------------------------------------
select tests.snapshot_counts();
select tests.authenticate_as('guard');
select is(
  tests.pick(public.record_scan(tests.qr('staff_pass'), tests.id('main_gate'), null, tests.id('ev_entry')),
             array['result', 'replayed']),
  '{"result": "entry_recorded", "replayed": true}',
  'replayed entry event returns entry_recorded, not a new exit');
select is(
  tests.pick(public.record_scan(tests.qr('staff_pass'), tests.id('main_gate'), null, tests.id('ev_exit')),
             array['result', 'replayed']),
  '{"result": "exit_recorded", "replayed": true}',
  'replayed exit event returns exit_recorded');
select is(
  tests.pick(public.record_scan(tests.qr('revoked_pass'), tests.id('main_gate'), null, tests.id('ev_blocked')),
             array['result']),
  '{"result": "revoked"}', 'first blocked scan with an event id');
select is(
  tests.pick(public.record_scan(tests.qr('revoked_pass'), tests.id('main_gate'), null, tests.id('ev_blocked')),
             array['result', 'replayed']),
  '{"result": "revoked", "replayed": true}', 'replayed blocked event returns the original result');
select is(public.record_scan('no-such-token', tests.id('main_gate'), null, tests.id('ev_invalid')) ->> 'result',
          'invalid', 'replayed invalid event is still invalid');
reset role;
select is((select count(*)::int from public.visits), tests.total('visits'), 'replays create no visits');
select is((select count(*)::int from public.flags), tests.total('flags') + 1, 'replays create no extra flags');
select is((select count(*)::int from public.visits where pass_id = tests.id('staff_pass') and exit_at is null), 1,
          'replays do not toggle the visit');

-- ---------------------------------------------------------------------------
-- Leaving is always recorded, offline timing
-- ---------------------------------------------------------------------------
update public.passes set status = 'revoked' where id = tests.id('staff_pass');
select tests.authenticate_as('guard');
select is(public.record_scan(tests.qr('staff_pass'), tests.id('main_gate')) ->> 'result', 'exit_recorded',
          'a pass revoked while the holder is inside still records the exit');
reset role;

update public.passes set valid_until = now() - interval '1 minute' where id = tests.id('other_pass');
select tests.authenticate_as('guard');
select is(public.record_scan(tests.qr('other_pass'), tests.id('main_gate'), now() - interval '2 hours') ->> 'result',
          'entry_recorded', 'offline scan made while the pass was valid is accepted after expiry');
reset role;
select ok((select recorded_offline and entry_at < now() - interval '119 minutes'
           from public.visits where pass_id = tests.id('other_pass') and exit_at is null),
          'offline scan keeps its original time and is marked recorded_offline');

select tests.authenticate_as('guard');
select ok((public.record_scan(tests.qr('decided_by_admin'), tests.id('main_gate'), now() + interval '1 day') ->> 'entry_at')::timestamptz <= now(),
          'a scan time in the future is clamped to now');

-- ---------------------------------------------------------------------------
-- Gate and caller checks
-- ---------------------------------------------------------------------------
select throws_ok(format('select public.record_scan(%L, %L)', tests.qr('decided_by_admin'), tests.id('closed_gate')),
                 '22023', 'gate_not_found', 'inactive gate is refused');
reset role;
select tests.authenticate_as('receptionist');
select ok(public.record_scan(tests.qr('decided_by_admin'), tests.id('main_gate')) ? 'result', 'receptionists can scan');
reset role;
select tests.authenticate_as('staff');
select throws_ok(format('select public.record_scan(%L, %L)', tests.qr('staff_pass'), tests.id('main_gate')),
                 '42501', 'not_authorized', 'staff cannot scan');
reset role;
select tests.authenticate_as('inactive_admin');
select throws_ok(format('select public.record_scan(%L, %L)', tests.qr('staff_pass'), tests.id('main_gate')),
                 '42501', 'not_authorized', 'deactivated operators cannot scan');
reset role;
select tests.authenticate_anon();
select throws_ok(format('select public.record_scan(%L, %L)', 'x', tests.id('main_gate')),
                 '42501', null, 'anon cannot call record_scan');
reset role;

select * from finish();
rollback;
