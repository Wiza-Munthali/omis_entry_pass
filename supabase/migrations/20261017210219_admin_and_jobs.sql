-- OMIS Entry — admin dashboard functions and the remaining scheduled jobs
-- (docs/SPEC.md → Scheduled jobs, Admin dashboard, Phase 8).
--
-- Jobs (pg_cron, UTC):
--   expire-passes        every 15 min   approved past valid_until → expired
--   auto-close-visits    every 5 min    open visits from before the last auto_close_time (CAT)
--                                       → closed at that time, auto_closed, flagged
--   cleanup-id-photos    daily 00:00    (02:00 CAT) photos past delete_after → removed by the
--                                       cleanup-id-photos Edge Function (storage needs its API)
--   purge-old-requests   Sundays 01:00  rejected / never-decided requests older than 90 days
--                                       → personal fields removed
-- Admin functions:
--   revoke_pass, extend_pass, admin_users, search_visits, dashboard_overview

-- ---------------------------------------------------------------------------
-- Jobs
-- ---------------------------------------------------------------------------
create function private.expire_passes()
returns int
language sql
security definer
set search_path = ''
as $$
  with e as (
    update public.passes set status = 'expired'
    where status = 'approved' and valid_until <= now()
    returning 1
  )
  select count(*)::int from e;
$$;

-- Closes visits still open from before the most recent auto-close moment. Using the
-- most recent moment (not just today's) means a missed run still closes yesterday's.
create function private.auto_close_visits()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today_close timestamptz;
  v_close timestamptz;
  v_visit record;
  v_count int := 0;
begin
  select private.local_midnight(private.local_today()) + s.auto_close_time
    into v_today_close
    from public.settings s;
  v_close := case when now() >= v_today_close then v_today_close else v_today_close - interval '1 day' end;

  for v_visit in
    update public.visits
    set exit_at = greatest(v_close, entry_at), auto_closed = true
    where exit_at is null and entry_at < v_close
    returning id, pass_id
  loop
    insert into public.flags (type, pass_id, visit_id, details)
    values ('auto_closed', v_visit.pass_id, v_visit.id, jsonb_build_object('closed_at', v_close));
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- Asks the cleanup-id-photos Edge Function to remove photos past delete_after
-- (files from the bucket, then rows). Nothing to do → no call.
create function private.request_id_photo_cleanup()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.id_photos where delete_after < now()) then
    return null;
  end if;
  return private.call_edge_function('cleanup-id-photos', '{}'::jsonb);
end;
$$;

-- Rejected or never-decided requests older than 90 days: the request keeps its
-- dates and outcome; contact and visit details go. People who only ever had such
-- requests (no account) lose their personal details and vehicles.
create function private.purge_old_requests()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count int;
begin
  with purged as (
    update public.passes
    set contact_email = null, contact_phone = null, host_name = null, purpose = null
    where type in ('day', 'week')
      and created_at < now() - interval '90 days'
      and (status = 'rejected' or decided_at is null)
      and (contact_email is not null or contact_phone is not null or host_name is not null or purpose is not null)
    returning person_id
  )
  select count(*) into v_count from purged;

  delete from public.vehicles ve
  using public.people pe
  where ve.person_id = pe.id
    and pe.profile_id is null
    and pe.full_name <> 'Removed'
    and not exists (
      select 1 from public.passes pa
      where pa.person_id = pe.id
        and not (pa.created_at < now() - interval '90 days' and (pa.status = 'rejected' or pa.decided_at is null))
    );

  update public.people pe
  set full_name = 'Removed', id_number = null, phone = null, email = null
  where pe.profile_id is null
    and pe.full_name <> 'Removed'
    and exists (select 1 from public.passes pa where pa.person_id = pe.id)
    and not exists (
      select 1 from public.passes pa
      where pa.person_id = pe.id
        and not (pa.created_at < now() - interval '90 days' and (pa.status = 'rejected' or pa.decided_at is null))
    );

  return v_count;
end;
$$;

revoke execute on function private.expire_passes() from public, anon, authenticated;
revoke execute on function private.auto_close_visits() from public, anon, authenticated;
revoke execute on function private.request_id_photo_cleanup() from public, anon, authenticated;
revoke execute on function private.purge_old_requests() from public, anon, authenticated;

select cron.schedule('expire-passes', '*/15 * * * *', 'select private.expire_passes()');
select cron.schedule('auto-close-visits', '*/5 * * * *', 'select private.auto_close_visits()');
select cron.schedule('cleanup-id-photos', '0 0 * * *', 'select private.request_id_photo_cleanup()');
select cron.schedule('purge-old-requests', '0 1 * * 0', 'select private.purge_old_requests()');

-- ---------------------------------------------------------------------------
-- Passes: revoke and extend (admins). Revoking emails the holder (notify-visitor).
-- ---------------------------------------------------------------------------
create function public.revoke_pass(p_pass_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pass public.passes;
begin
  if not private.has_role('admin') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  select * into v_pass from public.passes where id = p_pass_id for update;
  if not found then
    raise exception 'pass_not_found' using errcode = '22023';
  end if;
  if v_pass.status <> 'approved' then
    return jsonb_build_object('result', 'unchanged', 'status', v_pass.status);
  end if;

  update public.passes set status = 'revoked', decided_by = auth.uid(), decided_at = now()
  where id = p_pass_id;
  perform private.write_audit('revoke_pass', 'passes', p_pass_id::text,
                              jsonb_strip_nulls(jsonb_build_object('reason', private.clean(p_reason))));
  return jsonb_build_object('result', 'revoked', 'status', 'revoked');
end;
$$;

create function public.extend_pass(p_pass_id uuid, p_days int)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pass public.passes;
  v_until timestamptz;
begin
  if not private.has_role('admin') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  if p_days is null or p_days < 1 or p_days > 730 then
    raise exception 'days_out_of_range' using errcode = '22023';
  end if;
  select * into v_pass from public.passes where id = p_pass_id for update;
  if not found then
    raise exception 'pass_not_found' using errcode = '22023';
  end if;
  if v_pass.status not in ('approved', 'expired') then
    raise exception 'pass_not_extendable' using errcode = 'P0001';
  end if;

  v_until := greatest(v_pass.valid_until, now()) + make_interval(days => p_days);
  update public.passes set valid_until = v_until, status = 'approved' where id = p_pass_id;
  perform private.write_audit('extend_pass', 'passes', p_pass_id::text,
                              jsonb_build_object('days', p_days, 'valid_until', v_until));
  return jsonb_build_object('result', 'extended', 'valid_until', v_until);
end;
$$;

create function private.notify_holder_of_revocation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.call_edge_function('notify-visitor', jsonb_build_object('pass_id', new.id));
  return null;
end;
$$;

create trigger passes_notify_revoked
after update of status on public.passes
for each row
when (old.status = 'approved' and new.status = 'revoked')
execute function private.notify_holder_of_revocation();

-- ---------------------------------------------------------------------------
-- Users (A7): operators with when they last signed in (auth data, admins only).
-- ---------------------------------------------------------------------------
create function public.admin_users()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.has_role('admin') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'id', p.id,
      'full_name', p.full_name,
      'email', p.email,
      'role', p.role,
      'is_active', p.is_active,
      'created_at', p.created_at,
      'last_sign_in_at', u.last_sign_in_at
    )) order by p.is_active desc, p.role, p.full_name)
    from public.profiles p
    left join auth.users u on u.id = p.id
    where p.role in ('admin', 'receptionist', 'guard')
  ), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- Visits log (A3): search by name, plate or ID; filter by gate, pass type and
-- local dates (Africa/Blantyre); newest first, with the total for paging and export.
-- ---------------------------------------------------------------------------
create function public.search_visits(
  p_query text default null,
  p_gate_id uuid default null,
  p_pass_type public.pass_type default null,
  p_from date default null,
  p_to date default null,
  p_limit int default 25,
  p_offset int default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text := private.clean(p_query);
  v_plate text := private.normalize_plate(p_query);
  v_id text := private.normalize_id_number(p_query);
  v_from timestamptz := case when p_from is null then null else private.local_midnight(p_from) end;
  v_to timestamptz := case when p_to is null then null else private.local_midnight(p_to + 1) end;
  v_result jsonb;
begin
  if not private.has_role('receptionist') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  with matched as (
    select v.id, v.pass_id, v.entry_at, v.exit_at, v.auto_closed, v.recorded_offline, v.vehicle_plate,
           pe.full_name, pa.type as pass_type, g.name as gate_name
    from public.visits v
    join public.people pe on pe.id = v.person_id
    join public.passes pa on pa.id = v.pass_id
    join public.gates g on g.id = v.gate_id
    where (p_gate_id is null or v.gate_id = p_gate_id)
      and (p_pass_type is null or pa.type = p_pass_type)
      and (v_from is null or v.entry_at >= v_from)
      and (v_to is null or v.entry_at < v_to)
      and (
        v_q is null
        or pe.full_name ilike '%' || v_q || '%'
        or v.vehicle_plate like '%' || v_plate || '%'
        or pe.id_number = v_id
      )
  )
  select jsonb_build_object(
    'total', (select count(*) from matched),
    'rows', coalesce((
      select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'visit_id', m.id,
        'pass_id', m.pass_id,
        'full_name', m.full_name,
        'pass_type', m.pass_type,
        'plate', m.vehicle_plate,
        'gate_name', m.gate_name,
        'entry_at', m.entry_at,
        'exit_at', m.exit_at,
        'auto_closed', m.auto_closed,
        'recorded_offline', m.recorded_offline
      )) order by m.entry_at desc)
      from (select * from matched order by entry_at desc limit greatest(p_limit, 0) offset greatest(p_offset, 0)) m
    ), '[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Overview (A2): KPI row and today's entries per hour (Africa/Blantyre).
-- ---------------------------------------------------------------------------
create function public.dashboard_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_start timestamptz := private.local_midnight(private.local_today());
begin
  if not private.has_role('receptionist') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'on_site', (select count(*) from public.visits where exit_at is null),
    'entries_today', (select count(*) from public.visits where entry_at >= v_start),
    'pending_requests', (select count(*) from public.passes where status = 'pending' and type in ('day', 'week')),
    'escalated_requests', (select count(*) from public.passes
                           where status = 'pending' and escalated_at is not null and type in ('day', 'week')),
    'open_flags', (select count(*) from public.flags where resolved_at is null),
    'entries_by_hour', (
      select jsonb_agg(coalesce(c.n, 0) order by h.hour)
      from generate_series(0, 23) as h(hour)
      left join (
        select extract(hour from entry_at at time zone 'Africa/Blantyre')::int as hour, count(*) as n
        from public.visits
        where entry_at >= v_start
        group by 1
      ) c on c.hour = h.hour
    )
  );
end;
$$;

revoke execute on function public.revoke_pass(uuid, text) from public, anon;
revoke execute on function public.extend_pass(uuid, int) from public, anon;
revoke execute on function public.admin_users() from public, anon;
revoke execute on function public.search_visits(text, uuid, public.pass_type, date, date, int, int) from public, anon;
revoke execute on function public.dashboard_overview() from public, anon;
grant execute on function public.revoke_pass(uuid, text) to authenticated;
grant execute on function public.extend_pass(uuid, int) to authenticated;
grant execute on function public.admin_users() to authenticated;
grant execute on function public.search_visits(text, uuid, public.pass_type, date, date, int, int) to authenticated;
grant execute on function public.dashboard_overview() to authenticated;
