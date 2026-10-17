-- Visitor portal: submit_visitor_request (service role only, rate-limited),
-- get_request_status (public by secret token), and the decision triggers.
begin;
\ir helpers/setup.psql
select plan(41);

select tests.build_world();

create function pg_temp.submit(
  p_phone text default '+265 991 000 001',
  p_ip text default '10.0.0.1',
  p_id text default 'mw-new-1',
  p_name text default 'Chisomo Visitor',
  p_email text default 'Chisomo@Example.com',
  p_type public.pass_type default 'day',
  p_start date default null,
  p_purpose text default 'meeting'
) returns jsonb language sql as $$
  select public.submit_visitor_request(p_name, p_phone, p_email, p_id, 'Finance office', p_purpose,
                                       p_type, p_start, 'bt 77', p_ip);
$$;

-- ---------------------------------------------------------------------------
-- Who may submit
-- ---------------------------------------------------------------------------
select tests.authenticate_anon();
select throws_ok($$select public.submit_visitor_request('A','0991000000','a@b.co','X','H','meeting','day')$$,
                 '42501', null, 'anon cannot call submit_visitor_request directly');
reset role;
select tests.authenticate_as('receptionist');
select throws_ok($$select public.submit_visitor_request('A','0991000000','a@b.co','X','H','meeting','day')$$,
                 '42501', null, 'signed-in users cannot call it either');
reset role;
select ok(has_function_privilege('service_role',
  'public.submit_visitor_request(text,text,text,text,text,text,public.pass_type,date,text,text)', 'execute'),
  'the Edge Function (service role) can');

-- ---------------------------------------------------------------------------
-- A new request
-- ---------------------------------------------------------------------------
set local role service_role;
select tests.remember('req1', (pg_temp.submit() ->> 'pass_id')::uuid);
reset role;

select row_eq(
  format('select type, status, source, host_name, purpose, contact_email, contact_phone, requested_by
          from public.passes where id = %L', tests.id('req1')),
  row('day'::public.pass_type, 'pending'::public.pass_status, 'web'::public.request_source, 'Finance office'::text,
      'meeting'::text, 'chisomo@example.com'::text, '+265991000001'::text, null::uuid),
  'pending web request with contact details on the pass');
select row_eq(
  format('select valid_from, valid_until from public.passes where id = %L', tests.id('req1')),
  row(private.local_midnight(private.local_today()), private.local_midnight(private.local_today() + 1)),
  'day pass for today (Africa/Blantyre)');
select row_eq(
  format('select pe.full_name, pe.id_number, pe.phone, v.plate from public.passes p
          join public.people pe on pe.id = p.person_id join public.vehicles v on v.id = p.vehicle_id where p.id = %L',
         tests.id('req1')),
  row('Chisomo Visitor'::text, 'MW-NEW-1'::text, '+265991000001'::text, 'BT77'::text),
  'new person and vehicle, normalised');
select ok((select status_token is not null from public.passes where id = tests.id('req1')), 'status token issued');

-- Phone formats normalise to one number (rate limits key on it).
select is(private.normalize_phone('0991 234 567'), '+265991234567', 'local 0… format');
select is(private.normalize_phone('265-991-234-567'), '+265991234567', '265… format');
select is(private.normalize_phone('+265 (991) 234567'), '+265991234567', '+265 format');

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------
create temp table dates as select private.local_today() + 15 as too_late, private.local_today() - 1 as too_early;
grant select on dates to service_role;
set local role service_role;
select throws_ok($$select pg_temp.submit(p_purpose => 'party')$$, '22023', 'purpose_invalid', 'purpose from the list only');
select throws_ok($$select pg_temp.submit(p_email => 'not-an-email')$$, '22023', 'email_required', 'email required');
select throws_ok($$select pg_temp.submit(p_phone => '12')$$, '22023', 'phone_required', 'phone required');
select throws_ok($$select pg_temp.submit(p_type => 'staff')$$, '22023', 'pass_type_must_be_day_or_week', 'no staff passes');
select throws_ok(format($$select pg_temp.submit(p_start => %L)$$, (select too_late from dates)), '22023',
                 'start_date_out_of_range', 'at most 14 days ahead');
select throws_ok(format($$select pg_temp.submit(p_start => %L)$$, (select too_early from dates)), '22023',
                 'start_date_out_of_range', 'not in the past');
reset role;

-- ---------------------------------------------------------------------------
-- Returning visitor: matched on ID number, stored details never overwritten
-- ---------------------------------------------------------------------------
update public.people set phone = '+265888000000' where id = tests.id('visitor');
set local role service_role;
select tests.remember('req2', (pg_temp.submit(p_id => 't-vis-1', p_name => 'Someone Else', p_phone => '0991000002',
                                              p_email => 'other@example.com') ->> 'pass_id')::uuid);
reset role;
select is((select person_id from public.passes where id = tests.id('req2')), tests.id('visitor'), 'matched on ID number');
select row_eq(format('select full_name, phone from public.people where id = %L', tests.id('visitor')),
              row('Visitor One'::text, '+265888000000'::text), 'existing name and phone kept');
select is((select email from public.people where id = tests.id('visitor')), 'other@example.com', 'missing email filled in');
select is((select contact_email from public.passes where id = tests.id('req2')), 'other@example.com',
          'this request''s email kept on the request');

-- ---------------------------------------------------------------------------
-- Rate limiting: 5 per hour per phone and per IP
-- ---------------------------------------------------------------------------
set local role service_role;
-- Same phone, different networks. req1 already used +265991000001 once.
select pg_temp.submit(p_ip => '10.0.1.' || n, p_id => 'rl-phone-' || n) from generate_series(1, 4) n;
select throws_ok($$select pg_temp.submit(p_ip => '10.0.2.1', p_id => 'rl-phone-x')$$, 'P0001', 'rate_limited',
                 'sixth request from one phone in an hour is refused');
-- Same network, different phones.
select pg_temp.submit(p_ip => '192.168.5.5', p_phone => '0992000' || lpad(n::text, 3, '0'), p_id => 'rl-ip-' || n)
from generate_series(1, 5) n;
select throws_ok($$select pg_temp.submit(p_ip => '192.168.5.5', p_phone => '0993000000', p_id => 'rl-ip-x')$$,
                 'P0001', 'rate_limited', 'sixth request from one IP in an hour is refused');
select lives_ok($$select pg_temp.submit(p_ip => '192.168.5.6', p_phone => '0993000000', p_id => 'rl-ok')$$,
                'other phones on other networks are unaffected');
reset role;
select ok(not exists (select 1 from private.request_attempts where ip_hash like '%192.168%'),
          'IP addresses are stored hashed');
update private.request_attempts set created_at = now() - interval '61 minutes';
set local role service_role;
select lives_ok($$select pg_temp.submit(p_ip => '192.168.5.5', p_phone => '0993000001', p_id => 'rl-later')$$,
                'the limit resets after an hour');
reset role;

-- ---------------------------------------------------------------------------
-- Status page lookup
-- ---------------------------------------------------------------------------
select tests.remember('tok_holder', tests.id('req1'));
create function pg_temp.status(p_key text) returns jsonb language sql as $$
  select public.get_request_status((select status_token from public.passes where id = tests.id(p_key)));
$$;
grant execute on function pg_temp.status(text) to anon;
create temp table req1_token as select status_token from public.passes where id = tests.id('req1');
grant select on req1_token to anon;

select tests.authenticate_anon();
select is(tests.pick(public.get_request_status((select status_token from req1_token)),
                     array['status', 'full_name', 'pass_type', 'host_name', 'plate']),
          '{"status": "pending", "full_name": "Chisomo Visitor", "pass_type": "day", "host_name": "Finance office", "plate": "BT77"}',
          'anon with the link sees the pending request');
select ok(not (public.get_request_status((select status_token from req1_token)) ?| array['qr_token', 'id_number', 'phone', 'email', 'contact_email', 'contact_phone']),
          'no QR while pending, and no ID number, phone or email ever');
select is(public.get_request_status('not-a-real-token'), null, 'unknown token → nothing');
reset role;
select is(public.get_request_status((select status_token from public.passes where id = tests.id('staff_pass'))), null,
          'staff pass tokens are not visitor status links');

update public.passes set status = 'approved', decided_at = now() where id = tests.id('req1');
select is(pg_temp.status('req1') ->> 'status', 'approved', 'approved request shows approved');
select is(pg_temp.status('req1') ->> 'qr_token', (select qr_token from public.passes where id = tests.id('req1')),
          'approved request shows the QR');
update public.passes set status = 'rejected', reject_reason = 'Host away', decided_at = now() where id = tests.id('req2');
select is(tests.pick(pg_temp.status('req2'), array['status', 'reject_reason']),
          '{"status": "rejected", "reject_reason": "Host away"}', 'rejected request shows the reason');
update public.passes set valid_from = now() - interval '2 days', valid_until = now() - interval '1 day' where id = tests.id('req1');
select is(tests.pick(pg_temp.status('req1'), array['status', 'qr_token']), '{"status": "expired"}',
          'approved but past its dates → expired, no QR');

-- ---------------------------------------------------------------------------
-- Decision triggers
-- ---------------------------------------------------------------------------
set local role service_role;
select tests.remember('req3', (pg_temp.submit(p_ip => '10.9.9.9', p_phone => '0994000000', p_id => 'trig-1') ->> 'pass_id')::uuid);
reset role;
select tests.snapshot_counts();
create temp table q_before as select coalesce(max(id), 0) as id from net.http_request_queue;

select tests.authenticate_as('receptionist');
select public.decide_request(tests.id('req3'), 'approve');
reset role;
select ok(exists (select 1 from net.http_request_queue q, q_before b
                  where q.id > b.id and q.url like '%/notify-visitor'
                    and convert_from(q.body, 'utf8')::jsonb = jsonb_build_object('pass_id', tests.id('req3'))
                    and q.headers ? 'x-internal-secret'),
          'approving a web request queues notify-visitor with the shared secret');
select ok(exists (select 1 from realtime.messages
                  where topic = 'request:' || (select status_token from public.passes where id = tests.id('req3'))
                    and event = 'status_changed' and payload ->> 'status' = 'approved'),
          'and broadcasts the new status to the status page');

truncate q_before; insert into q_before select coalesce(max(id), 0) from net.http_request_queue;
select tests.authenticate_as('receptionist');
select public.decide_request(tests.id('gate_pending'), 'approve');
reset role;
select ok(not exists (select 1 from net.http_request_queue q, q_before b where q.id > b.id),
          'gate requests (no email) send nothing');
select ok(exists (select 1 from realtime.messages
                  where topic = 'request:' || (select status_token from public.passes where id = tests.id('gate_pending'))),
          'gate requests still broadcast (guard screen, Phase 6)');

-- Without the Vault entries the decision still stands; nothing is sent.
delete from vault.secrets where name = 'functions_url';
set local role service_role;
select tests.remember('req4', (pg_temp.submit(p_ip => '10.9.9.8', p_phone => '0995000000', p_id => 'trig-2') ->> 'pass_id')::uuid);
reset role;
truncate q_before; insert into q_before select coalesce(max(id), 0) from net.http_request_queue;
select tests.authenticate_as('admin');
select lives_ok(format($$select public.decide_request(%L, 'reject', 'No space')$$, tests.id('req4')),
                'a decision works even if email is not configured');
reset role;
select ok(not exists (select 1 from net.http_request_queue q, q_before b where q.id > b.id), 'and sends nothing');

-- Contact details stay out of the audit log.
select ok(not exists (select 1 from public.audit_log where details::text like '%chisomo@example.com%'
                                                        or details::text like '%+265991000001%'),
          'contact email and phone are not copied into the audit log');

-- Anyone else: no direct access to the rate-limit table.
select tests.authenticate_as('admin');
select throws_ok('select * from private.request_attempts', '42501', null, 'request_attempts is not readable by users');
reset role;

select * from finish();
rollback;
