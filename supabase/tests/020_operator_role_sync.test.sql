-- Invited operators get their role even though Supabase Auth writes app_metadata
-- after creating the user (regression: invites used to become "staff").
begin;
\ir helpers/setup.psql
select plan(5);

-- How auth.admin.createUser behaves: insert without a role, then set app_metadata.
select tests.create_user('invited', null);
select is((select role::text from public.profiles where id = tests.id('invited')), 'staff', 'starts as staff');
update auth.users set raw_app_meta_data = raw_app_meta_data || '{"role": "receptionist"}' where id = tests.id('invited');
select is((select role::text from public.profiles where id = tests.id('invited')), 'receptionist',
          'the role from app_metadata is applied when it is set');

-- Later admin changes live on profiles and are not undone by unrelated auth updates.
update public.profiles set role = 'guard' where id = tests.id('invited');
update auth.users set raw_app_meta_data = raw_app_meta_data || '{"provider": "email"}' where id = tests.id('invited');
select is((select role::text from public.profiles where id = tests.id('invited')), 'guard',
          'other app_metadata updates do not reset a changed role');

-- user_metadata (which users can set themselves) never grants a role.
select tests.create_user('selfie', null);
update auth.users set raw_user_meta_data = '{"role": "admin"}' where id = tests.id('selfie');
select is((select role::text from public.profiles where id = tests.id('selfie')), 'staff', 'user_metadata role ignored');
update auth.users set raw_app_meta_data = raw_app_meta_data || '{"role": "superuser"}' where id = tests.id('selfie');
select is((select role::text from public.profiles where id = tests.id('selfie')), 'staff', 'unknown roles ignored');

select * from finish();
rollback;
