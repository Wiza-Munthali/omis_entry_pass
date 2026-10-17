-- Phase 6: scan-and-approve, the guard's own requests, returning visitors,
-- check-in without a QR, approver notifications and escalation.
begin;
\ir helpers/setup.psql
select plan(35);

select tests.build_world();
create temp table q_before (id bigint);
insert into q_before select coalesce(max(id), 0) from net.http_request_queue;
grant select on q_before to authenticated;

-- ---------------------------------------------------------------------------
-- Scan-and-approve: approvers scanning a pending request raise no flag
-- ---------------------------------------------------------------------------
select tests.snapshot_counts();
select tests.authenticate_as('receptionist');
select is(tests.pick(public.record_scan(tests.qr('web_pending'), tests.id('main_gate')), array['result', 'pass_id']),
          jsonb_build_object('result', 'pending', 'pass_id', tests.id('web_pending')),
          'receptionist scanning a pending QR gets the request id to review');
reset role;
select is((select count(*)::int from public.flags), tests.total('flags'), 'and no flag is raised');
select tests.authenticate_as('guard');
select is(public.record_scan(tests.qr('web_pending'), tests.id('main_gate')) ->> 'result', 'pending', 'guard: pending');
reset role;
select is((select count(*)::int from public.flags), tests.total('flags') + 1, 'a guard turning someone away is still flagged');

-- ---------------------------------------------------------------------------
-- create_gate_request returns the status token; approvers are notified
-- ---------------------------------------------------------------------------
truncate q_before; insert into q_before select coalesce(max(id), 0) from net.http_request_queue;
select tests.authenticate_as('guard');
create temp table new_req as
  select public.create_gate_request('Mphatso Kalua', 'MW-P6-1', 'day', 'Finance', 'meeting') as r;
reset role;
select ok((select r ? 'status_token' and r ? 'pass_id' from new_req), 'create_gate_request returns pass id and status token');
select ok(exists (select 1 from net.http_request_queue q, q_before b
                  where q.id > b.id and q.url like '%/notify-approvers'
                    and convert_from(q.body, 'utf8')::jsonb
                        = jsonb_build_object('pass_id', (select (r ->> 'pass_id')::uuid from new_req), 'kind', 'new')),
          'a new request queues notify-approvers (kind new)');

truncate q_before; insert into q_before select coalesce(max(id), 0) from net.http_request_queue;
insert into public.passes (person_id, type, status, valid_from, valid_until)
values (tests.id('staff_person'), 'staff', 'approved', now(), now() + interval '1 year');
select ok(not exists (select 1 from net.http_request_queue q, q_before b where q.id > b.id and q.url like '%/notify-approvers'),
          'staff passes notify nobody');

-- ---------------------------------------------------------------------------
-- my_gate_requests: the guard's own requests only
-- ---------------------------------------------------------------------------
select tests.authenticate_as('guard');
select ok((select bool_and(r ? 'status_token') and count(*) >= 2
           from jsonb_array_elements(public.my_gate_requests()) r),
          'guard sees their requests with status tokens');
select ok(exists (select 1 from jsonb_array_elements(public.my_gate_requests()) r
                  where r ->> 'full_name' = 'Mphatso Kalua' and r ->> 'status' = 'pending'),
          'including the new pending one');
select ok(not exists (select 1 from jsonb_array_elements(public.my_gate_requests()) r
                      where r ->> 'pass_id' = tests.id('web_pending')::text),
          'not web requests');
reset role;
select tests.authenticate_as('guard2');
select is(public.my_gate_requests(), '[]'::jsonb, 'another guard sees none of them');
reset role;

update public.passes set status = 'rejected', reject_reason = 'Host away', decided_at = now()
where id = (select (r ->> 'pass_id')::uuid from new_req);
select tests.authenticate_as('guard');
select is((select r ->> 'reject_reason' from jsonb_array_elements(public.my_gate_requests()) r
           where r ->> 'full_name' = 'Mphatso Kalua'), 'Host away', 'rejection reason shown to the guard');
reset role;
select tests.authenticate_as('staff');
select is(public.my_gate_requests(), '[]'::jsonb, 'staff get nothing');
reset role;
select tests.authenticate_anon();
select throws_ok('select public.my_gate_requests()', '42501', null, 'anon cannot call my_gate_requests');
reset role;

-- ---------------------------------------------------------------------------
-- find_visitor_passes: approved, valid visitor passes by name or exact ID
-- ---------------------------------------------------------------------------
select tests.authenticate_as('guard');
select ok(exists (select 1 from jsonb_array_elements(public.find_visitor_passes('visitor one')) r
                  where r ->> 'pass_id' = tests.id('decided_by_rec')::text),
          'found by name (case-insensitive)');
select ok(exists (select 1 from jsonb_array_elements(public.find_visitor_passes('t-vis-1')) r
                  where r ->> 'pass_id' = tests.id('decided_by_rec')::text and r ->> 'id_last4' = 'IS-1'
                    and (r ->> 'on_site')::boolean),
          'found by exact ID number; shows last 4 of the ID and whether they are on site');
select ok(not exists (select 1 from jsonb_array_elements(public.find_visitor_passes('t-vis-1')) r where r ? 'id_number'),
          'never returns the full ID number');
select ok(not exists (select 1 from jsonb_array_elements(public.find_visitor_passes('Visitor')) r
                      where r ->> 'pass_id' in (tests.id('web_pending')::text, tests.id('gate_pending')::text)),
          'pending requests are not offered for check-in');
select ok(not exists (select 1 from jsonb_array_elements(public.find_visitor_passes('Staff Person')) r),
          'staff passes are not visitor passes');
select is(public.find_visitor_passes('Vi'), '[]'::jsonb, 'at least 3 characters');
reset role;
select tests.authenticate_as('staff');
select throws_ok($$select public.find_visitor_passes('Visitor')$$, '42501', 'not_authorized', 'staff cannot search');
reset role;

-- ---------------------------------------------------------------------------
-- check_in_pass: like scanning, without the QR
-- ---------------------------------------------------------------------------
select tests.authenticate_as('guard');
select is(public.check_in_pass(tests.id('decided_by_admin'), tests.id('main_gate')) ->> 'result', 'entry_recorded',
          'approved visitor pass checks in');
select is(public.check_in_pass(tests.id('decided_by_admin'), tests.id('main_gate')) ->> 'result', 'exit_recorded',
          'and out again');
select is(public.check_in_pass(tests.id('gate_pending'), tests.id('main_gate')) ->> 'result', 'pending',
          'a pending request cannot be checked in');
select throws_ok(format('select public.check_in_pass(%L, %L)', tests.id('staff_pass'), tests.id('main_gate')),
                 '22023', 'pass_not_found', 'staff passes are scanned, not checked in by id');
reset role;
select tests.authenticate_as('staff');
select throws_ok(format('select public.check_in_pass(%L, %L)', tests.id('decided_by_admin'), tests.id('main_gate')),
                 '42501', 'not_authorized', 'staff cannot check people in');
reset role;

-- ---------------------------------------------------------------------------
-- Escalation
-- ---------------------------------------------------------------------------
update public.settings set approval_timeout_minutes = 5;
update public.passes set created_at = now() - interval '6 minutes' where id = tests.id('gate_pending');
update public.passes set created_at = now() - interval '2 minutes' where id = tests.id('web_pending');
-- An old pending request whose day is over is not escalated.
with r as (
  insert into public.passes (person_id, type, valid_from, valid_until, source, created_at)
  values (tests.id('visitor2'), 'day', now() - interval '2 days', now() - interval '1 day', 'web', now() - interval '2 days')
  returning id
) insert into tests.ids select 'stale', id from r;
-- Earlier pending requests in this database (e.g. the dev seed) are out of scope here.
update public.passes set escalated_at = now()
where status = 'pending' and id not in (tests.id('gate_pending'), tests.id('web_pending'), tests.id('stale'));

truncate q_before; insert into q_before select coalesce(max(id), 0) from net.http_request_queue;
select is(private.escalate_overdue_requests(), 1, 'one request is past the 5-minute timeout');
select ok((select escalated_at is not null from public.passes where id = tests.id('gate_pending')), 'it is marked escalated');
select ok((select escalated_at is null from public.passes where id = tests.id('web_pending')), 'newer requests wait');
select ok((select escalated_at is null from public.passes where id = tests.id('stale')), 'expired requests are left alone');
select ok(exists (select 1 from public.flags where type = 'approval_escalated' and pass_id = tests.id('gate_pending')),
          'an approval_escalated flag is raised');
select ok(exists (select 1 from net.http_request_queue q, q_before b
                  where q.id > b.id and q.url like '%/notify-approvers'
                    and convert_from(q.body, 'utf8')::jsonb = jsonb_build_object('pass_id', tests.id('gate_pending'), 'kind', 'escalated')),
          'admins are notified (notify-approvers, kind escalated)');
select is(private.escalate_overdue_requests(), 0, 'each request escalates only once');

select is((select schedule from cron.job where jobname = 'escalate-approvals'), '* * * * *', 'escalation runs every minute');
select ok(exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'passes'),
          'passes changes reach the receptionist queue via Realtime');

select * from finish();
rollback;
