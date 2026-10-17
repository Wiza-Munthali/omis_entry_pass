-- Staff portal: the before_user_created hook (domain check) and portal_config.
begin;
\ir helpers/setup.psql
select plan(10);

update public.settings set allowed_email_domains = array['GHII.test', 'ghii.org'];

create function pg_temp.hook(p_email text, p_app_meta jsonb default '{}') returns jsonb language sql as $$
  select private.before_user_created(jsonb_build_object(
    'metadata', jsonb_build_object('name', 'before-user-created'),
    'user', jsonb_build_object('email', p_email, 'app_metadata', p_app_meta)));
$$;

select is(pg_temp.hook('wiza@ghii.test'), '{}', 'allowed domain may sign up');
select is(pg_temp.hook('Wiza@GHII.ORG'), '{}', 'domain match ignores case');
select is(pg_temp.hook('wiza@gmail.com') #>> '{error,http_code}', '403', 'other domains are refused with 403');
select is(pg_temp.hook('wiza@ghii.test.evil.com') #>> '{error,http_code}', '403', 'look-alike domains are refused');
select is(pg_temp.hook('guard@gmail.com', '{"role": "guard"}'), '{}', 'operators invited with a role may use any domain');
select is(pg_temp.hook('x@gmail.com', '{"role": "staff"}') #>> '{error,http_code}', '403',
          'a staff role in app_metadata does not bypass the domain check');

select ok(has_function_privilege('supabase_auth_admin', 'private.before_user_created(jsonb)', 'execute'),
          'auth server can run the hook');
select ok(not has_function_privilege('authenticated', 'private.before_user_created(jsonb)', 'execute')
          and not has_function_privilege('anon', 'private.before_user_created(jsonb)', 'execute'),
          'API roles cannot run the hook');

select tests.authenticate_anon();
select is(public.portal_config(), '{"org_name": "GHII", "allowed_email_domains": ["GHII.test", "ghii.org"]}',
          'anon reads organisation name and allowed domains');
select ok(not (public.portal_config() ? 'approval_timeout_minutes'), 'portal_config exposes nothing else');
reset role;

select * from finish();
rollback;
