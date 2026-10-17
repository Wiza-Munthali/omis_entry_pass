-- Offline scanning: fingerprints, the phone's cache, syncing offline scans, conflicts.
begin;
\ir helpers/setup.psql
select plan(24);

select tests.build_world();
create temp table h as
  select id, qr_token_hash as hash from public.passes;
grant select on h to authenticated;

create function pg_temp.hash(p_key text) returns text language sql stable as $$
  select hash from h where id = tests.id(p_key);
$$;
grant execute on function pg_temp.hash(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Fingerprints
-- ---------------------------------------------------------------------------
select is(pg_temp.hash('staff_pass'),
          encode(extensions.digest(tests.qr('staff_pass'), 'sha256'), 'hex'),
          'qr_token_hash is sha256(qr_token) in hex');
select ok(pg_temp.hash('staff_pass') ~ '^[0-9a-f]{64}$', '64 hex characters');

-- ---------------------------------------------------------------------------
-- The phone's cache
-- ---------------------------------------------------------------------------
select tests.authenticate_as('guard');
create temp table cache as select public.offline_pass_cache() as c;
reset role;

select ok(exists (select 1 from cache, jsonb_array_elements(c -> 'passes') p
                  where p ->> 'token_hash' = pg_temp.hash('staff_pass')
                    and p ->> 'full_name' = 'Staff Person' and p ->> 'plate' = 'TT1001'),
          'approved staff pass cached with name and plate');
select ok(exists (select 1 from cache, jsonb_array_elements(c -> 'passes') p
                  where p ->> 'pass_id' = tests.id('decided_by_rec')::text),
          'approved visitor pass cached');
select ok(not exists (select 1 from cache, jsonb_array_elements(c -> 'passes') p
                      where p ->> 'pass_id' in (tests.id('web_pending')::text, tests.id('gate_pending')::text)),
          'pending requests are not cached');
select ok(not exists (select 1 from cache, jsonb_array_elements(c -> 'passes') p where p ? 'qr_token'),
          'never the raw QR token');
select ok(not exists (select 1 from cache, jsonb_array_elements(c -> 'passes') p
                      where p::text like '%' || tests.qr('staff_pass') || '%'),
          'the token does not appear anywhere in the cache');
select ok(exists (select 1 from cache, jsonb_array_elements(c -> 'open_visits') v
                  where v ->> 'visit_id' = tests.id('open_visit')::text),
          'open visits are cached so the phone can tell entry from exit');

select tests.authenticate_as('staff');
select throws_ok('select public.offline_pass_cache()', '42501', 'not_authorized', 'staff cannot download the cache');
reset role;

-- ---------------------------------------------------------------------------
-- Syncing offline scans
-- ---------------------------------------------------------------------------
select tests.remember('ev1', gen_random_uuid());
select tests.remember('ev2', gen_random_uuid());
select tests.remember('ev3', gen_random_uuid());
select tests.remember('ev4', gen_random_uuid());

select tests.authenticate_as('guard');
select is(tests.pick(public.record_offline_scan(pg_temp.hash('other_pass'), tests.id('main_gate'),
                                                 now() - interval '40 minutes', tests.id('ev1')),
                     array['result', 'full_name']),
          '{"result": "entry_recorded", "full_name": "Other Staff"}', 'offline entry syncs');
select is(public.record_offline_scan(pg_temp.hash('other_pass'), tests.id('main_gate'),
                                     now() - interval '40 minutes', tests.id('ev1')) ->> 'replayed',
          'true', 'a forced retry of the same event is a replay');
select is(public.record_offline_scan(pg_temp.hash('other_pass'), tests.id('main_gate'),
                                     now() - interval '10 minutes', tests.id('ev2')) ->> 'result',
          'exit_recorded', 'the next offline scan is the exit');
reset role;
select row_eq(
  format($$select count(*)::int, bool_and(recorded_offline), min(entry_at) < now() - interval '39 minutes'
           from public.visits where pass_id = %L$$, tests.id('other_pass')),
  row(1, true, true),
  'one visit, marked offline, with the original entry time');

select tests.authenticate_as('guard');
select is(public.record_offline_scan(repeat('0', 64), tests.id('main_gate'), now(), gen_random_uuid()),
          '{"result": "invalid"}', 'unknown fingerprint is invalid');
select throws_ok(format($$select public.record_offline_scan(%L, %L, now(), null)$$, pg_temp.hash('other_pass'), tests.id('main_gate')),
                 '22023', 'event_id_and_time_required', 'offline scans must carry an event id');
reset role;

-- ---------------------------------------------------------------------------
-- Conflicts: the pass changed while the phone was offline
-- ---------------------------------------------------------------------------
update public.passes set status = 'revoked' where id = tests.id('decided_by_admin');
select tests.snapshot_counts();
select tests.authenticate_as('guard');
select is(tests.pick(public.record_offline_scan(pg_temp.hash('decided_by_admin'), tests.id('main_gate'),
                                                 now() - interval '20 minutes', tests.id('ev3')),
                     array['result', 'conflict']),
          '{"result": "entry_recorded", "conflict": "revoked"}',
          'a pass revoked meanwhile is still recorded (they are inside), with the conflict');
reset role;
select ok(exists (select 1 from public.flags where type = 'offline_conflict' and pass_id = tests.id('decided_by_admin')
                    and details ->> 'result' = 'revoked' and details ->> 'scanned_by' = tests.id('guard')::text),
          'an offline_conflict flag is raised for review');
select ok(not exists (select 1 from public.flags where type = 'scan_invalid_pass' and pass_id = tests.id('decided_by_admin')),
          'not a scan_invalid_pass flag');
select tests.authenticate_as('guard');
select is(public.record_offline_scan(pg_temp.hash('decided_by_admin'), tests.id('main_gate'),
                                     now() - interval '20 minutes', tests.id('ev3')) ->> 'replayed',
          'true', 'retrying the conflicting scan does not flag twice');
reset role;
select is((select count(*)::int from public.flags), tests.total('flags') + 1, 'still exactly one new flag');

-- Online scans are never let through on conflict, even with an old scan time
-- (a phone whose clock is behind must not open the gate for a revoked pass).
update public.visits set exit_at = now() where pass_id = tests.id('decided_by_admin') and exit_at is null;
select tests.authenticate_as('guard');
select is(public.record_scan('no-such-token', tests.id('main_gate')) ->> 'result', 'invalid',
          'unknown token online is invalid');
select is(public.record_scan(tests.qr('decided_by_admin'), tests.id('main_gate'), now() - interval '2 hours', tests.id('ev4')) ->> 'result',
          'revoked', 'an online scan of a revoked pass is refused, whatever scanned_at says');
reset role;
select ok(not exists (select 1 from public.visits where client_entry_id = tests.id('ev4')), 'and nothing is recorded');

-- The fingerprint stays out of the audit log.
select ok(not exists (select 1 from public.audit_log a, h where a.details::text like '%' || h.hash || '%'),
          'no fingerprints in the audit log');

select * from finish();
rollback;
