-- decide_request: receptionist or above; first decision wins; reason required to reject;
-- every decision is in the audit log.
begin;
\ir helpers/setup.psql
select plan(17);

select tests.build_world();
with r as (
  insert into public.passes (person_id, type, valid_from, valid_until, source)
  values (tests.id('visitor2'), 'day', now() - interval '2 days', now() - interval '1 day', 'web')
  returning id
) insert into tests.ids select 'stale_pending', id from r;

-- Who may decide
select tests.authenticate_as('guard');
select throws_ok(format('select public.decide_request(%L, %L)', tests.id('web_pending'), 'approve'),
                 '42501', 'not_authorized', 'guards cannot approve');
reset role;
select tests.authenticate_as('staff');
select throws_ok(format('select public.decide_request(%L, %L)', tests.id('web_pending'), 'approve'),
                 '42501', 'not_authorized', 'staff cannot approve');
reset role;
select tests.authenticate_anon();
select throws_ok(format('select public.decide_request(%L, %L)', tests.id('web_pending'), 'approve'),
                 '42501', null, 'anon cannot call decide_request');
reset role;
select is((select status::text from public.passes where id = tests.id('web_pending')), 'pending', 'still pending');

-- Approve
select tests.authenticate_as('receptionist');
select is(tests.pick(public.decide_request(tests.id('web_pending'), 'approve'), array['result', 'status', 'decided_by']),
          jsonb_build_object('result', 'approved', 'status', 'approved', 'decided_by', tests.id('receptionist')),
          'receptionist approves a pending request');
reset role;
select ok((select status = 'approved' and decided_by = tests.id('receptionist') and decided_at is not null
           from public.passes where id = tests.id('web_pending')), 'pass approved with decider and time');
select row_eq(
  format($$select actor_id, details from public.audit_log where action = 'decide_request' and target_id = %L$$,
         tests.id('web_pending')),
  row(tests.id('receptionist'), '{"decision": "approved"}'::jsonb),
  'decision written to the audit log with the decider');

-- First decision wins
select tests.authenticate_as('admin');
select is(tests.pick(public.decide_request(tests.id('web_pending'), 'reject', 'Too late'),
                     array['result', 'status', 'decided_by_name']),
          '{"result": "already_decided", "status": "approved", "decided_by_name": "receptionist"}',
          'a later decision returns already_decided and who decided');
reset role;
select is((select status::text from public.passes where id = tests.id('web_pending')), 'approved',
          'the first decision stands');

-- Reject
select tests.authenticate_as('admin');
select throws_ok(format('select public.decide_request(%L, %L, %L)', tests.id('gate_pending'), 'reject', '  '),
                 '22023', 'reason_required', 'rejecting needs a reason');
select is(public.decide_request(tests.id('gate_pending'), 'reject', 'No host available') ->> 'result', 'rejected',
          'admin rejects with a reason');
reset role;
select is((select reject_reason from public.passes where id = tests.id('gate_pending')), 'No host available',
          'reason stored');

-- Input checks
select tests.authenticate_as('receptionist');
select throws_ok(format('select public.decide_request(%L, %L)', tests.id('stale_pending'), 'maybe'),
                 '22023', 'decision_must_be_approve_or_reject', 'unknown decision refused');
select throws_ok(format('select public.decide_request(%L, %L)', gen_random_uuid(), 'approve'),
                 '22023', 'request_not_found', 'unknown request refused');
select throws_ok(format('select public.decide_request(%L, %L)', tests.id('stale_pending'), 'approve'),
                 'P0001', 'request_expired', 'a request whose dates have passed cannot be approved');
select is(public.decide_request(tests.id('stale_pending'), 'reject', 'Expired') ->> 'result', 'rejected',
          'but it can still be rejected');
reset role;

-- Deactivated operators cannot decide
select tests.authenticate_as('inactive_admin');
select throws_ok(format('select public.decide_request(%L, %L)', tests.id('decided_by_admin'), 'approve'),
                 '42501', 'not_authorized', 'deactivated admin cannot decide');
reset role;

select * from finish();
rollback;
