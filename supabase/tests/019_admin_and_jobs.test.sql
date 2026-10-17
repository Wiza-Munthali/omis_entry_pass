-- Phase 8: scheduled jobs and admin dashboard functions.
begin;
\ir helpers/setup.psql
select plan(32);

select tests.build_world();
create temp table q_before (id bigint);
insert into q_before select coalesce(max(id), 0) from net.http_request_queue;

-- ---------------------------------------------------------------------------
-- expire-passes
-- ---------------------------------------------------------------------------
update public.passes set valid_from = now() - interval '2 days', valid_until = now() - interval '1 minute'
where id = tests.id('other_pass');
select ok(private.expire_passes() >= 1, 'expire_passes reports what it changed');
select is((select status::text from public.passes where id = tests.id('other_pass')), 'expired', 'approved past its end → expired');
select is((select status::text from public.passes where id = tests.id('staff_pass')), 'approved', 'valid passes untouched');
select is(private.expire_passes(), 0, 'running again changes nothing');

-- ---------------------------------------------------------------------------
-- auto-close-visits: open visits from before the last auto-close moment
-- ---------------------------------------------------------------------------
update public.settings set auto_close_time = '23:59';
create temp table close_moment as
  select case
    when now() >= private.local_midnight(private.local_today()) + time '23:59'
      then private.local_midnight(private.local_today()) + time '23:59'
    else private.local_midnight(private.local_today()) + time '23:59' - interval '1 day'
  end as at;
-- An open visit from before the last close (a missed night) and the existing fresh one.
update public.visits set entry_at = (select at from close_moment) - interval '3 hours'
where id = tests.id('open_visit');
with r as (
  insert into public.visits (pass_id, person_id, gate_id, entry_at)
  values (tests.id('staff_pass'), tests.id('staff_person'), tests.id('main_gate'), now())
  returning id
) insert into tests.ids select 'fresh_visit', id from r;

select is(private.auto_close_visits(), 1, 'one visit left open past the close time');
select row_eq(format('select exit_at = (select at from close_moment), auto_closed from public.visits where id = %L', tests.id('open_visit')),
              row(true, true), 'closed at the close time and marked auto_closed');
select ok(exists (select 1 from public.flags where type = 'auto_closed' and visit_id = tests.id('open_visit')),
          'an auto_closed flag is raised');
select ok((select exit_at is null from public.visits where id = tests.id('fresh_visit'))
          or (select at from close_moment) > now(), 'visits after the close time stay open');
select is(private.auto_close_visits(), 0, 'nothing more to close');

-- ---------------------------------------------------------------------------
-- cleanup-id-photos: the database asks the Edge Function only when photos are due
-- ---------------------------------------------------------------------------
truncate q_before; insert into q_before select coalesce(max(id), 0) from net.http_request_queue;
update public.id_photos set delete_after = now() + interval '1 day';
select is(private.request_id_photo_cleanup(), null, 'nothing due → no call');
update public.id_photos set delete_after = now() - interval '1 minute' where id = tests.id('photo_admin');
select ok(private.request_id_photo_cleanup() is not null, 'photos due → cleanup requested');
select ok(exists (select 1 from net.http_request_queue q, q_before b where q.id > b.id and q.url like '%/cleanup-id-photos'),
          'the cleanup-id-photos function is called');

-- ---------------------------------------------------------------------------
-- purge-old-requests
-- ---------------------------------------------------------------------------
with r as (insert into public.people (full_name, id_number, phone, email) values ('Old Visitor', 'T-OLD', '+265 1', 'o@x.y') returning id)
insert into tests.ids select 'old_person', id from r;
insert into public.vehicles (person_id, plate) values (tests.id('old_person'), 'OLD1');
with r as (
  insert into public.passes (person_id, type, status, valid_from, valid_until, source, host_name, purpose,
                             contact_email, contact_phone, reject_reason, decided_at, created_at)
  values (tests.id('old_person'), 'day', 'rejected', now() - interval '100 days', now() - interval '99 days', 'web',
          'Finance', 'meeting', 'o@x.y', '+265 1', 'No', now() - interval '100 days', now() - interval '100 days')
  returning id
) insert into tests.ids select 'old_request', id from r;
-- A visitor with an old rejection but a recent approved pass keeps their details.
with r as (
  insert into public.passes (person_id, type, status, valid_from, valid_until, source, host_name, contact_email,
                             reject_reason, decided_at, created_at)
  values (tests.id('visitor'), 'day', 'rejected', now() - interval '100 days', now() - interval '99 days', 'web',
          'HR', 'v@x.y', 'No', now() - interval '100 days', now() - interval '100 days')
  returning id
) insert into tests.ids select 'old_request_2', id from r;

select is(private.purge_old_requests(), 2, 'two old requests purged');
select row_eq(format('select host_name, purpose, contact_email, contact_phone, status::text from public.passes where id = %L', tests.id('old_request')),
              row(null::text, null::text, null::text, null::text, 'rejected'::text), 'contact and visit details removed, outcome kept');
select row_eq(format('select full_name, id_number, phone, email from public.people where id = %L', tests.id('old_person')),
              row('Removed'::text, null::text, null::text, null::text), 'a person with only old requests is anonymised');
select is((select count(*)::int from public.vehicles where person_id = tests.id('old_person')), 0, 'and their vehicles deleted');
select is((select full_name from public.people where id = tests.id('visitor')), 'Visitor One',
          'people with recent passes keep their details');
select is(private.purge_old_requests(), 0, 'running again changes nothing');

-- ---------------------------------------------------------------------------
-- revoke_pass / extend_pass
-- ---------------------------------------------------------------------------
truncate q_before; insert into q_before select coalesce(max(id), 0) from net.http_request_queue;
select tests.authenticate_as('admin');
select is(public.revoke_pass(tests.id('staff_pass'), 'Left GHII') ->> 'result', 'revoked', 'admin revokes a staff pass');
select is(public.revoke_pass(tests.id('staff_pass')) ->> 'result', 'unchanged', 'revoking twice changes nothing');
select is(public.extend_pass(tests.id('other_pass'), 30) ->> 'result', 'extended', 'admin extends an expired pass');
reset role;
select ok(exists (select 1 from net.http_request_queue q, q_before b
                  where q.id > b.id and q.url like '%/notify-visitor'
                    and convert_from(q.body, 'utf8')::jsonb = jsonb_build_object('pass_id', tests.id('staff_pass'))),
          'the holder is emailed about the revocation');
select ok(exists (select 1 from public.audit_log where action = 'revoke_pass' and target_id = tests.id('staff_pass')::text
                    and details ->> 'reason' = 'Left GHII' and actor_id = tests.id('admin')),
          'revocation audited with reason and admin');
select ok((select status = 'approved' and valid_until > now() + interval '29 days' from public.passes where id = tests.id('other_pass')),
          'extended pass is approved again for 30 more days');
select tests.authenticate_as('admin');
select throws_ok(format('select public.extend_pass(%L, 30)', tests.id('staff_pass')), 'P0001', 'pass_not_extendable',
                 'revoked passes cannot be extended');
reset role;
select tests.authenticate_as('receptionist');
select throws_ok(format('select public.revoke_pass(%L)', tests.id('decided_by_rec')), '42501', 'not_authorized',
                 'receptionists cannot revoke');
reset role;

-- ---------------------------------------------------------------------------
-- admin_users, search_visits, dashboard_overview
-- ---------------------------------------------------------------------------
select tests.authenticate_as('admin');
select ok((select bool_and(u ->> 'role' in ('admin', 'receptionist', 'guard')) and count(*) >= 6
           from jsonb_array_elements(public.admin_users()) u), 'admin_users lists operators only');
reset role;
select tests.authenticate_as('receptionist');
select throws_ok('select public.admin_users()', '42501', 'not_authorized', 'only admins list users');
reset role;

select tests.authenticate_as('admin');
select is((public.search_visits('visitor one') -> 'rows' -> 0 ->> 'full_name'), 'Visitor One', 'search by name');
select is((public.search_visits('tt 2002') ->> 'total')::int, 1, 'search by plate, spaces ignored');
select is((public.search_visits(null, null, 'staff') -> 'rows' -> 0 ->> 'pass_type'), 'staff', 'filter by pass type');
select ok((public.dashboard_overview() -> 'entries_by_hour') is not null
          and jsonb_array_length(public.dashboard_overview() -> 'entries_by_hour') = 24, 'overview has 24 hourly buckets');
reset role;

select * from finish();
rollback;
