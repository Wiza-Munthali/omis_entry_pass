-- request_detail: receptionists and admins see a request with the operators' names;
-- ID photo paths follow the same rule as the storage policy.
begin;
\ir helpers/setup.psql
select plan(8);

select tests.build_world();

select tests.authenticate_as('receptionist');
select is(tests.pick(public.request_detail(tests.id('gate_pending')),
                     array['status', 'full_name', 'id_number', 'source', 'requested_by_name']),
          '{"status": "pending", "full_name": "Visitor One", "id_number": "T-VIS-1", "source": "gate", "requested_by_name": "guard"}',
          'receptionist sees the request, ID number and who registered it');
select is(public.request_detail(tests.id('gate_pending')) -> 'photo_paths',
          jsonb_build_array(tests.id('gate_pending') || '/a.jpg'), 'and the ID photo of a pending request');
select is(public.request_detail(tests.id('decided_by_rec')) ->> 'decided_by_name', 'receptionist', 'who decided');
select ok(not (public.request_detail(tests.id('decided_by_admin')) ? 'photo_paths'),
          'no photo paths for a request someone else decided');
select throws_ok(format('select public.request_detail(%L)', tests.id('staff_pass')), '22023', 'request_not_found',
                 'staff passes are not requests');
reset role;

select tests.authenticate_as('admin');
select is(public.request_detail(tests.id('decided_by_admin')) -> 'photo_paths',
          jsonb_build_array(tests.id('decided_by_admin') || '/c.jpg'), 'admins see every photo path');
reset role;

select tests.authenticate_as('guard');
select throws_ok(format('select public.request_detail(%L)', tests.id('gate_pending')), '42501', 'not_authorized',
                 'guards cannot open request details');
reset role;
select tests.authenticate_anon();
select throws_ok(format('select public.request_detail(%L)', tests.id('gate_pending')), '42501', null, 'anon cannot');
reset role;

select * from finish();
rollback;
