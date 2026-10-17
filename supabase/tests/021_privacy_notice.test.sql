-- Phase 9: privacy notice facts, privacy contact setting, rate-limit cleanup.
begin;
\ir helpers/setup.psql
select plan(11);

select tests.build_world();
update public.settings set id_photo_retention_days = 30, privacy_contact = null;

-- Anyone can read the notice's facts, including visitors who are not signed in.
select tests.authenticate_anon();
select is(public.privacy_notice() ->> 'id_photo_retention_days', '30', 'anon reads the ID photo retention');
select is(public.privacy_notice() ->> 'request_retention_days', '90', 'and the request purge period');
select is(public.privacy_notice() ->> 'rate_limit_retention_hours', '24', 'and the rate-limit window');
select ok(public.privacy_notice() ? 'privacy_contact', 'and the privacy contact (empty until set)');
select is((select array_agg(k order by k) from jsonb_object_keys(public.privacy_notice()) k),
          array['id_photo_retention_days', 'org_name', 'privacy_contact', 'rate_limit_retention_hours', 'request_retention_days'],
          'nothing else is exposed (no email domains, timeouts or other settings)');
reset role;

-- Only admins set the privacy contact.
select tests.authenticate_as('admin');
select lives_ok($$update public.settings set privacy_contact = 'privacy@ghii.test'$$, 'admin sets the privacy contact');
reset role;
select tests.authenticate_as('staff');
select is(public.privacy_notice() ->> 'privacy_contact', 'privacy@ghii.test', 'the notice shows it');
reset role;
select tests.authenticate_as('guard');
with u as (update public.settings set privacy_contact = 'x' returning 1)
select is(count(*)::int, 0, 'guards cannot change it') from u;
reset role;
select throws_ok($$update public.settings set privacy_contact = repeat('x', 201)$$, '23514', null,
                 'the contact is at most 200 characters');

-- Rate-limit records older than a day are cleared by the hourly job.
insert into private.request_attempts (ip_hash, phone, created_at)
values ('old', '+265 1', now() - interval '25 hours'), ('new', '+265 2', now() - interval '1 hour');
select is(private.purge_request_attempts(), 1, 'records older than a day are deleted');
select is((select count(*)::int from private.request_attempts where ip_hash in ('old', 'new')), 1, 'recent ones stay');

select * from finish();
rollback;
