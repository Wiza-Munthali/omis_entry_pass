-- register_staff_pass: verified staff on an allowed domain get an approved staff pass;
-- calling again returns the same pass with updated details.
begin;
\ir helpers/setup.psql
select plan(21);

select tests.build_world();
update public.settings set allowed_email_domains = array['TEST.invalid'], staff_pass_days = 365;
select tests.create_user('newstaff', 'staff');
select tests.create_user('revokedstaff', 'staff');
select tests.create_user('expiredstaff', 'staff');
select tests.create_user('outsider', 'staff');
update auth.users set email = 'outsider@gmail.com' where id = tests.id('outsider');

-- ---------------------------------------------------------------------------
-- First registration
-- ---------------------------------------------------------------------------
select tests.authenticate_as('newstaff');
select tests.remember('new_pass', (public.register_staff_pass(' Thoko  Banda ', 'mw 9001', 'bt 777') ->> 'pass_id')::uuid);
select results_eq('select id from public.passes', array[tests.id('new_pass')], 'staff can read their new pass');
select row_eq('select type, status, source from public.passes',
              row('staff'::public.pass_type, 'approved'::public.pass_status, 'web'::public.request_source),
              'pass is an approved staff pass, no approval needed');
select ok((select valid_until between now() + interval '364 days' and now() + interval '366 days' from public.passes),
          'valid for staff_pass_days (365)');
select row_eq('select full_name, id_number, email from public.people',
              row('Thoko  Banda'::text, 'MW9001'::text, 'newstaff@test.invalid'::text),
              'person saved: trimmed name, normalised ID number, profile email');
select is((select plate from public.vehicles), 'BT777', 'vehicle saved with normalised plate');
select is((select v.plate from public.passes p join public.vehicles v on v.id = p.vehicle_id), 'BT777',
          'pass carries the vehicle');
select is((select full_name from public.profiles where id = auth.uid()), 'Thoko  Banda', 'profile name updated');
select is((public.register_staff_pass('Thoko Banda', 'MW9001') -> 'qr_token') is not null, true,
          'response includes the QR token');
reset role;

-- ---------------------------------------------------------------------------
-- Calling again: same pass, updated details
-- ---------------------------------------------------------------------------
select tests.authenticate_as('newstaff');
select is((public.register_staff_pass('Thoko Banda-Phiri', 'MW9001', 'zz 1') ->> 'pass_id')::uuid, tests.id('new_pass'),
          're-registering returns the same pass');
select is((select full_name from public.people), 'Thoko Banda-Phiri', 'name updated');
select is((select v.plate from public.passes p join public.vehicles v on v.id = p.vehicle_id), 'ZZ1',
          'vehicle switched');
select is((public.register_staff_pass('Thoko Banda-Phiri', 'MW9001') ->> 'pass_id')::uuid, tests.id('new_pass'),
          'still the same pass without a vehicle');
select is((select vehicle_id from public.passes), null, '"I drive to work" off clears the vehicle');
select is((select count(*)::int from public.passes), 1, 'only one pass exists');
reset role;

-- ---------------------------------------------------------------------------
-- Refusals
-- ---------------------------------------------------------------------------
select tests.authenticate_as('outsider');
select throws_ok($$select public.register_staff_pass('Out Sider', 'MW1')$$, '42501', 'email_domain_not_allowed',
                 'email outside the allowed domains is refused');
reset role;

select tests.authenticate_as('newstaff');
select throws_ok($$select public.register_staff_pass('Thoko', 't-vis-1')$$, 'P0001', 'id_number_in_use',
                 'cannot claim an ID number already on someone else''s record');
select throws_ok($$select public.register_staff_pass('  ', 'MW9001')$$, '22023', 'full_name_required', 'name required');
reset role;

-- Revoked: never silently replaced. Expired: a fresh pass is issued.
with r as (insert into public.people (profile_id, full_name, id_number) values (tests.id('revokedstaff'), 'R', 'T-R') returning id)
insert into public.passes (person_id, type, status, valid_from, valid_until)
select id, 'staff', 'revoked', now() - interval '10 days', now() + interval '300 days' from r;
with r as (insert into public.people (profile_id, full_name, id_number) values (tests.id('expiredstaff'), 'E', 'T-E') returning id)
insert into public.passes (person_id, type, status, valid_from, valid_until)
select id, 'staff', 'expired', now() - interval '400 days', now() - interval '35 days' from r;

select tests.authenticate_as('revokedstaff');
select throws_ok($$select public.register_staff_pass('R', 'T-R')$$, 'P0001', 'pass_revoked',
                 'a revoked staff pass is not replaced');
reset role;
select tests.authenticate_as('expiredstaff');
select is(public.register_staff_pass('E', 'T-E') ->> 'status', 'approved', 'an expired staff pass is renewed');
select is((select count(*)::int from public.passes), 2, 'renewal is a new pass; the old one stays for history');
reset role;

select tests.authenticate_anon();
select throws_ok($$select public.register_staff_pass('A', 'B')$$, '42501', null, 'anon cannot call register_staff_pass');
reset role;

select * from finish();
rollback;
