-- Row counts that a restore must reproduce (written next to each backup as counts.txt).
select 'auth.users', count(*) from auth.users
union all select 'public.profiles', count(*) from public.profiles
union all select 'public.people', count(*) from public.people
union all select 'public.vehicles', count(*) from public.vehicles
union all select 'public.gates', count(*) from public.gates
union all select 'public.passes', count(*) from public.passes
union all select 'public.visits', count(*) from public.visits
union all select 'public.id_photos', count(*) from public.id_photos
union all select 'public.flags', count(*) from public.flags
union all select 'public.settings', count(*) from public.settings
union all select 'public.audit_log', count(*) from public.audit_log
union all select 'storage.objects', count(*) from storage.objects
order by 1;
