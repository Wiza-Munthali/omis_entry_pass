-- OMIS Entry — approvals and gate requests (docs/SPEC.md → Core flows 3 and 4, Phase 6).
--
--   record_scan          (changed) approvers scanning a pending request raise no flag
--   create_gate_request  (changed) also returns status_token for the guard's live screen
--   my_gate_requests     the guard's own recent requests (waiting list, G3/G9)
--   find_visitor_passes  returning visitors: search valid visitor passes by name or ID
--   check_in_pass        check in by pass, without a QR (approved gate request, returning visitor)
--   on new request       notify-approvers (email + push to active receptionists)
--   escalation           every minute: pending past approval_timeout_minutes → flag, admins notified
--   Realtime             passes in the supabase_realtime publication (receptionist queue; RLS applies)

create or replace function public.record_scan(
  p_qr_token text,
  p_gate_id uuid,
  p_scanned_at timestamptz default null,
  p_client_event_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  -- A device clock ahead of the server cannot record the future.
  v_at timestamptz := least(coalesce(p_scanned_at, now()), now());
  v_offline boolean := p_scanned_at is not null and p_scanned_at < now() - interval '1 minute';
  v_pass public.passes;
  v_visit public.visits;
  v_plate text;
  v_result text;
  v_replay jsonb;
begin
  if not private.has_role('guard') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  if not exists (select 1 from public.gates where id = p_gate_id and is_active) then
    raise exception 'gate_not_found' using errcode = '22023';
  end if;

  -- 1. Unknown code. Nothing is written, so a replay gives the same answer.
  select * into v_pass from public.passes where qr_token = p_qr_token for update;
  if not found then
    return jsonb_build_object('result', 'invalid');
  end if;

  -- 6. Seen this event before: return the original result without writing.
  --    Checked after locking the pass so concurrent retries of one event serialise.
  v_replay := private.scan_replay(p_client_event_id);
  if v_replay is not null then
    return v_replay;
  end if;

  -- 3. Open visit → exit (always allowed, see header).
  select * into v_visit from public.visits where pass_id = v_pass.id and exit_at is null;
  if found then
    update public.visits
    set exit_at = greatest(v_at, entry_at),
        exit_by = v_actor,
        client_exit_id = p_client_event_id,
        recorded_offline = recorded_offline or v_offline
    where id = v_visit.id
    returning * into v_visit;
    return private.scan_payload('exit_recorded', v_pass.id, v_visit);
  end if;

  -- 2. Not allowed in: wrong status or outside the validity window.
  v_result := case
    when v_pass.status <> 'approved' then v_pass.status::text
    when v_at >= v_pass.valid_until then 'expired'
    when v_at < v_pass.valid_from then 'not_yet_valid'
  end;
  if v_result is not null then
    -- A receptionist or admin scanning a pending request is about to review it
    -- (scan-and-approve), not a guard turning someone away: no flag.
    if v_result = 'pending' and private.has_role('receptionist') then
      return private.scan_payload(v_result, v_pass.id, null);
    end if;
    insert into public.flags (type, pass_id, details)
    values ('scan_invalid_pass', v_pass.id, jsonb_strip_nulls(jsonb_build_object(
      'result', v_result,
      'gate_id', p_gate_id,
      'scanned_at', v_at,
      'scanned_by', v_actor,
      'client_event_id', p_client_event_id
    )));
    return private.scan_payload(v_result, v_pass.id, null);
  end if;

  -- 4. Entry, with the plate from the pass.
  select plate into v_plate from public.vehicles where id = v_pass.vehicle_id;
  insert into public.visits (
    pass_id, person_id, gate_id, vehicle_plate, entry_at, entry_by, client_entry_id, recorded_offline
  ) values (
    v_pass.id, v_pass.person_id, p_gate_id, v_plate, v_at, v_actor, p_client_event_id, v_offline
  )
  returning * into v_visit;
  return private.scan_payload('entry_recorded', v_pass.id, v_visit);
end;
$$;

create or replace function public.create_gate_request(
  p_full_name text,
  p_id_number text,
  p_pass_type public.pass_type,
  p_host_name text,
  p_purpose text,
  p_phone text default null,
  p_plate text default null,
  p_start_date date default null,
  p_client_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := private.local_today();
  v_start date := coalesce(p_start_date, v_today);
  v_name text := private.clean(p_full_name);
  v_id_number text := private.normalize_id_number(p_id_number);
  v_host text := private.clean(p_host_name);
  v_purpose text := private.clean(p_purpose);
  v_week_days int;
  v_person_id uuid;
  v_vehicle_id uuid;
  v_pass public.passes;
begin
  if not private.has_role('guard') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  if p_client_request_id is not null then
    select * into v_pass from public.passes where client_request_id = p_client_request_id;
    if found then
      return jsonb_build_object('pass_id', v_pass.id, 'status', v_pass.status, 'status_token', v_pass.status_token,
                                'valid_from', v_pass.valid_from, 'valid_until', v_pass.valid_until,
                                'replayed', true);
    end if;
  end if;

  if v_name is null then
    raise exception 'full_name_required' using errcode = '22023';
  end if;
  if v_id_number is null then
    raise exception 'id_number_required' using errcode = '22023';
  end if;
  if v_host is null then
    raise exception 'host_name_required' using errcode = '22023';
  end if;
  if v_purpose is null then
    raise exception 'purpose_required' using errcode = '22023';
  end if;
  if p_pass_type is null or p_pass_type not in ('day', 'week') then
    raise exception 'pass_type_must_be_day_or_week' using errcode = '22023';
  end if;
  if v_start < v_today or v_start > v_today + 14 then
    raise exception 'start_date_out_of_range' using errcode = '22023';
  end if;

  insert into public.people (full_name, id_number, phone)
  values (v_name, v_id_number, private.clean(p_phone))
  on conflict (id_number) do update
    set phone = coalesce(excluded.phone, people.phone)
  returning id into v_person_id;

  v_vehicle_id := private.upsert_vehicle(v_person_id, p_plate);

  select week_pass_days into v_week_days from public.settings;

  insert into public.passes (
    person_id, vehicle_id, type, status, valid_from, valid_until,
    host_name, purpose, source, requested_by, client_request_id
  ) values (
    v_person_id, v_vehicle_id, p_pass_type, 'pending',
    private.local_midnight(v_start),
    case p_pass_type
      when 'day' then private.local_midnight(v_start + 1)
      else private.local_midnight(v_start) + make_interval(days => v_week_days)
    end,
    v_host, v_purpose, 'gate', auth.uid(), p_client_request_id
  )
  returning * into v_pass;

  return jsonb_build_object('pass_id', v_pass.id, 'status', v_pass.status, 'status_token', v_pass.status_token,
                            'valid_from', v_pass.valid_from, 'valid_until', v_pass.valid_until);
end;
$$;

-- ---------------------------------------------------------------------------
-- The guard's own requests, newest first (last 24 hours, or still pending).
-- Guards cannot read passes, so this returns only what their screens show.
-- ---------------------------------------------------------------------------
create function public.my_gate_requests()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(r order by r ->> 'requested_at' desc), '[]'::jsonb)
  from (
    select jsonb_strip_nulls(jsonb_build_object(
      'pass_id', pa.id,
      'status_token', pa.status_token,
      'status', case when pa.status = 'approved' and pa.valid_until <= now() then 'expired' else pa.status::text end,
      'full_name', pe.full_name,
      'pass_type', pa.type,
      'host_name', pa.host_name,
      'plate', ve.plate,
      'requested_at', pa.created_at,
      'escalated_at', pa.escalated_at,
      'decided_at', pa.decided_at,
      'reject_reason', case when pa.status = 'rejected' then pa.reject_reason end,
      'on_site', exists (select 1 from public.visits v where v.pass_id = pa.id and v.exit_at is null)
    )) as r
    from public.passes pa
    join public.people pe on pe.id = pa.person_id
    left join public.vehicles ve on ve.id = pa.vehicle_id
    where pa.requested_by = auth.uid()
      and pa.source = 'gate'
      and (pa.status = 'pending' or pa.created_at > now() - interval '24 hours')
      and private.has_role('guard')
  ) s;
$$;

comment on function public.my_gate_requests is 'The calling operator''s gate requests: pending, or created in the last 24 hours.';

-- ---------------------------------------------------------------------------
-- Returning visitors: approved visitor passes valid now, by name or ID number.
-- Returns the last 4 characters of the ID only, for the guard to compare with the card.
-- ---------------------------------------------------------------------------
create function public.find_visitor_passes(p_query text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text := private.clean(p_query);
  v_id text := private.normalize_id_number(p_query);
begin
  if not private.has_role('guard') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  if v_q is null or length(v_q) < 3 then
    return '[]'::jsonb;
  end if;

  return coalesce((
    select jsonb_agg(r order by r ->> 'full_name')
    from (
      select jsonb_strip_nulls(jsonb_build_object(
        'pass_id', pa.id,
        'full_name', pe.full_name,
        'id_last4', right(pe.id_number, 4),
        'pass_type', pa.type,
        'plate', ve.plate,
        'host_name', pa.host_name,
        'valid_until', pa.valid_until,
        'on_site', exists (select 1 from public.visits v where v.pass_id = pa.id and v.exit_at is null)
      )) as r
      from public.passes pa
      join public.people pe on pe.id = pa.person_id
      left join public.vehicles ve on ve.id = pa.vehicle_id
      where pa.type in ('day', 'week')
        and pa.status = 'approved'
        and now() >= pa.valid_from and now() < pa.valid_until
        and (pe.full_name ilike '%' || v_q || '%' or pe.id_number = v_id)
      limit 10
    ) s
  ), '[]'::jsonb);
end;
$$;

comment on function public.find_visitor_passes is 'Approved, currently valid visitor passes by name or exact ID number. Operators only.';

-- ---------------------------------------------------------------------------
-- Check in by pass id (no QR): the "Check in now" after approval, and returning
-- visitors found by search. Same rules and result as scanning the pass.
-- ---------------------------------------------------------------------------
create function public.check_in_pass(p_pass_id uuid, p_gate_id uuid, p_client_event_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token text;
begin
  if not private.has_role('guard') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  select qr_token into v_token from public.passes where id = p_pass_id and type in ('day', 'week');
  if v_token is null then
    raise exception 'pass_not_found' using errcode = '22023';
  end if;
  return public.record_scan(v_token, p_gate_id, now(), p_client_event_id);
end;
$$;

comment on function public.check_in_pass is 'Record entry or exit for a visitor pass without scanning it. Operators only.';

revoke execute on function public.my_gate_requests() from public, anon;
revoke execute on function public.find_visitor_passes(text) from public, anon;
revoke execute on function public.check_in_pass(uuid, uuid, uuid) from public, anon;
grant execute on function public.my_gate_requests() to authenticated;
grant execute on function public.find_visitor_passes(text) to authenticated;
grant execute on function public.check_in_pass(uuid, uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- New request → notify approvers (email + push), after commit via pg_net.
-- ---------------------------------------------------------------------------
create function private.notify_approvers_of_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.call_edge_function('notify-approvers', jsonb_build_object('pass_id', new.id, 'kind', 'new'));
  return null;
end;
$$;

create trigger passes_notify_approvers
after insert on public.passes
for each row
when (new.status = 'pending' and new.type in ('day', 'week'))
execute function private.notify_approvers_of_request();

-- ---------------------------------------------------------------------------
-- Escalation: pending requests nobody decided within approval_timeout_minutes.
-- Runs every minute (pg_cron). Each request escalates once.
-- ---------------------------------------------------------------------------
create function private.escalate_overdue_requests()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_timeout int;
  v_pass record;
  v_count int := 0;
begin
  select approval_timeout_minutes into v_timeout from public.settings;

  for v_pass in
    update public.passes
    set escalated_at = now()
    where status = 'pending'
      and escalated_at is null
      and created_at < now() - make_interval(mins => v_timeout)
      and valid_until > now()
    returning id, created_at
  loop
    insert into public.flags (type, pass_id, details)
    values ('approval_escalated', v_pass.id,
            jsonb_build_object('waited_minutes', floor(extract(epoch from now() - v_pass.created_at) / 60)));
    perform private.call_edge_function('notify-approvers',
                                       jsonb_build_object('pass_id', v_pass.id, 'kind', 'escalated'));
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke execute on function private.escalate_overdue_requests() from public, anon, authenticated;

create extension if not exists pg_cron;
grant usage on schema cron to postgres;

select cron.schedule('escalate-approvals', '* * * * *', 'select private.escalate_overdue_requests()');

-- ---------------------------------------------------------------------------
-- Realtime: the receptionist queue listens for changes to passes. RLS still
-- applies, so guards, staff and anon receive nothing they could not select.
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table public.passes;
