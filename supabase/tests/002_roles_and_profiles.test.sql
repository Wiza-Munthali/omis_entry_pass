-- has_role ranking, profile creation from auth users, and the profiles policies.
-- Spec: roles form admin > receptionist > guard; staff are not operators; the role is
-- read from profiles, never from the client.
begin;
\ir helpers/setup.psql
select plan(36);

select tests.build_world();

-- ---------------------------------------------------------------------------
-- has_role(min_role): rank comparison, inactive and anonymous users get nothing
-- ---------------------------------------------------------------------------
create function pg_temp.roles_of(p_key text) returns text language plpgsql as $$
declare
  result text;
begin
  perform tests.authenticate_as(p_key);
  select concat_ws(',',
    case when private.has_role('guard') then 'guard' end,
    case when private.has_role('receptionist') then 'receptionist' end,
    case when private.has_role('admin') then 'admin' end,
    case when private.has_role('staff') then 'staff' end)
  into result;
  reset role;
  return result;
end;
$$;

select is(pg_temp.roles_of('admin'), 'guard,receptionist,admin', 'admin has every operator rank');
select is(pg_temp.roles_of('receptionist'), 'guard,receptionist', 'receptionist inherits guard');
select is(pg_temp.roles_of('guard'), 'guard', 'guard is guard only');
select is(pg_temp.roles_of('staff'), '', 'staff have no operator rank');
select is(pg_temp.roles_of('inactive_admin'), '', 'deactivated admin has no rank');

select tests.authenticate_anon();
select throws_ok($$select private.has_role('guard')$$, '42501', null, 'anonymous caller cannot reach role helpers');
reset role;

-- ---------------------------------------------------------------------------
-- New auth users get a profile; role only from app_metadata
-- ---------------------------------------------------------------------------
select is((select role::text from public.profiles where id = tests.id('guard')), 'guard', 'app_metadata role is applied');
select tests.create_user('self_promoted', null, '{"role": "admin", "full_name": "Sneaky"}');
select is((select role::text from public.profiles where id = tests.id('self_promoted')), 'staff',
          'role in user_metadata is ignored');
select is((select full_name from public.profiles where id = tests.id('self_promoted')), 'Sneaky',
          'full_name is taken from user_metadata');
select tests.create_user('weird_role', 'superuser');
select is((select role::text from public.profiles where id = tests.id('weird_role')), 'staff',
          'unknown role falls back to staff');
select is((select email from public.profiles where id = tests.id('staff')), 'staff@test.invalid', 'email copied from auth');
update auth.users set email = 'staff.new@test.invalid' where id = tests.id('staff');
select is((select email from public.profiles where id = tests.id('staff')), 'staff.new@test.invalid',
          'email change in auth is synced');

-- ---------------------------------------------------------------------------
-- profiles SELECT: own row, admins all
-- ---------------------------------------------------------------------------
select tests.snapshot_counts();
select tests.authenticate_as('staff');
select results_eq('select id from public.profiles', array[tests.id('staff')], 'staff reads only own profile');
reset role;
select tests.authenticate_as('guard');
select results_eq('select id from public.profiles', array[tests.id('guard')], 'guard reads only own profile');
reset role;
select tests.authenticate_as('receptionist');
select results_eq('select id from public.profiles', array[tests.id('receptionist')], 'receptionist reads only own profile');
reset role;
select tests.authenticate_as('admin');
select is((select count(*)::int from public.profiles), tests.total('profiles'), 'admin reads all profiles');
reset role;
select tests.authenticate_as('inactive_admin');
select is((select count(*)::int from public.profiles), 1, 'deactivated admin reads only own profile');
reset role;
select tests.authenticate_anon();
select throws_ok('select * from public.profiles', '42501', null, 'anon cannot read profiles');
reset role;

-- ---------------------------------------------------------------------------
-- profiles UPDATE: own name/phone/push token; role and is_active admin-only
-- ---------------------------------------------------------------------------
select tests.authenticate_as('staff');
select lives_ok($$update public.profiles set fcm_token = 'tok-1', phone = '+265 1', full_name = 'S P'
                  where id = tests.id('staff')$$, 'staff updates own name, phone and push token');
reset role;
select is((select fcm_token from public.profiles where id = tests.id('staff')), 'tok-1', 'own update applied');

select tests.authenticate_as('staff');
select throws_ok($$update public.profiles set role = 'admin' where id = tests.id('staff')$$,
                 '42501', null, 'staff cannot change own role');
select throws_ok($$update public.profiles set is_active = false where id = tests.id('staff')$$,
                 '42501', null, 'staff cannot change own is_active');
select throws_ok($$update public.profiles set email = 'x@y.z' where id = tests.id('staff')$$,
                 '42501', null, 'email is not client-writable');
with u as (update public.profiles set full_name = 'Hacked' where id = tests.id('other_staff') returning 1)
select is(count(*)::int, 0, 'staff cannot update another profile') from u;
reset role;

select tests.authenticate_as('guard');
select throws_ok($$update public.profiles set role = 'receptionist' where id = tests.id('guard')$$,
                 '42501', null, 'guard cannot promote self');
reset role;

select tests.authenticate_as('receptionist');
with u as (update public.profiles set is_active = false where id = tests.id('guard') returning 1)
select is(count(*)::int, 0, 'receptionist cannot deactivate a guard (row not visible)') from u;
select throws_ok($$update public.profiles set role = 'admin' where id = tests.id('receptionist')$$,
                 '42501', null, 'receptionist cannot promote self');
reset role;

select tests.authenticate_as('admin');
select lives_ok($$update public.profiles set role = 'receptionist' where id = tests.id('guard2')$$,
                'admin changes another user''s role');
select lives_ok($$update public.profiles set is_active = false where id = tests.id('receptionist2')$$,
                'admin deactivates another user');
select throws_ok($$update public.profiles set role = 'guard' where id = tests.id('admin')$$,
                 '42501', null, 'admin cannot change own role');
select throws_ok($$update public.profiles set is_active = false where id = tests.id('admin')$$,
                 '42501', null, 'admin cannot deactivate self');
reset role;
select is((select role::text from public.profiles where id = tests.id('guard2')), 'receptionist', 'role change applied');
select ok(not (select is_active from public.profiles where id = tests.id('receptionist2')), 'deactivation applied');

select tests.authenticate_as('inactive_admin');
with u as (update public.profiles set role = 'admin' where id = tests.id('guard') returning 1)
select is(count(*)::int, 0, 'deactivated admin cannot change others') from u;
reset role;

-- No client inserts or deletes on profiles (they come from auth.users).
select tests.authenticate_as('admin');
select throws_ok($$insert into public.profiles (id, email) values (gen_random_uuid(), 'a@b.c')$$,
                 '42501', null, 'admin cannot insert profiles directly');
select throws_ok($$delete from public.profiles where id = tests.id('guard')$$,
                 '42501', null, 'admin cannot delete profiles directly');
reset role;

select * from finish();
rollback;
