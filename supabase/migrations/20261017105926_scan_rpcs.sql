-- OMIS Entry — gate scanning (docs/SPEC.md → Core flows → 5. Scanning at the gate).
--
-- record_scan(qr_token, gate_id, scanned_at, client_event_id) is the single entry point
-- for scans; check_out(visit_id, client_event_id) is the manual check-out from the
-- on-site list. Both are idempotent on client_event_id so offline retries are safe.
--
-- Results: entry_recorded, exit_recorded, invalid, pending, rejected, revoked, expired,
-- not_yet_valid (check_out also: already_checked_out). Replays add "replayed": true.
--
-- Two deliberate refinements of the spec's step order:
--   * An open visit is always closed, whatever the pass status. Someone whose pass was
--     revoked or expired while inside must still be recorded leaving.
--   * Validity is judged at scanned_at, not at sync time, so an offline scan of a pass
--     that was valid at the gate is not rejected because it synced after expiry.

-- Response body shared by both RPCs.
create function private.scan_payload(p_result text, p_pass_id uuid, p_visit public.visits)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'result', p_result,
    'pass_id', pa.id,
    'full_name', pe.full_name,
    'pass_type', pa.type,
    'pass_status', pa.status,
    'plate', coalesce(p_visit.vehicle_plate, ve.plate),
    'valid_until', pa.valid_until,
    'visit_id', p_visit.id,
    'gate_id', p_visit.gate_id,
    'entry_at', p_visit.entry_at,
    'exit_at', p_visit.exit_at,
    'duration_seconds', extract(epoch from p_visit.exit_at - p_visit.entry_at)::int
  ))
  from public.passes pa
  join public.people pe on pe.id = pa.person_id
  left join public.vehicles ve on ve.id = pa.vehicle_id
  where pa.id = p_pass_id;
$$;

-- The original response for a client_event_id seen before, or null.
create function private.scan_replay(p_client_event_id uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_visit public.visits;
  v_flag public.flags;
begin
  if p_client_event_id is null then
    return null;
  end if;

  select * into v_visit from public.visits where client_entry_id = p_client_event_id;
  if found then
    -- Report the entry as it was recorded, even if the visit has since closed.
    v_visit.exit_at := null;
    return private.scan_payload('entry_recorded', v_visit.pass_id, v_visit) || '{"replayed": true}';
  end if;

  select * into v_visit from public.visits where client_exit_id = p_client_event_id;
  if found then
    return private.scan_payload('exit_recorded', v_visit.pass_id, v_visit) || '{"replayed": true}';
  end if;

  select * into v_flag
  from public.flags
  where details ? 'client_event_id' and details ->> 'client_event_id' = p_client_event_id::text
  limit 1;
  if found then
    return private.scan_payload(v_flag.details ->> 'result', v_flag.pass_id, null) || '{"replayed": true}';
  end if;

  return null;
end;
$$;

create function public.record_scan(
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

comment on function public.record_scan is
  'Scan a pass at a gate: records entry or exit, or explains why the pass is blocked. Operators only.';

create function public.check_out(p_visit_id uuid, p_client_event_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_visit public.visits;
  v_replay jsonb;
begin
  if not private.has_role('guard') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select * into v_visit from public.visits where id = p_visit_id for update;
  if not found then
    raise exception 'visit_not_found' using errcode = '22023';
  end if;

  v_replay := private.scan_replay(p_client_event_id);
  if v_replay is not null then
    return v_replay;
  end if;

  if v_visit.exit_at is not null then
    return private.scan_payload('already_checked_out', v_visit.pass_id, v_visit);
  end if;

  update public.visits
  set exit_at = greatest(now(), entry_at),
      exit_by = auth.uid(),
      client_exit_id = p_client_event_id
  where id = v_visit.id
  returning * into v_visit;
  return private.scan_payload('exit_recorded', v_visit.pass_id, v_visit);
end;
$$;

comment on function public.check_out is 'Manually check someone out from the on-site list. Operators only.';

revoke execute on function public.record_scan(text, uuid, timestamptz, uuid) from public, anon;
revoke execute on function public.check_out(uuid, uuid) from public, anon;
grant execute on function public.record_scan(text, uuid, timestamptz, uuid) to authenticated;
grant execute on function public.check_out(uuid, uuid) to authenticated;
