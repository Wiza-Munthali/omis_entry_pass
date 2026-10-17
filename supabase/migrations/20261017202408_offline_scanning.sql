-- OMIS Entry — offline scanning (docs/SPEC.md → Offline sync, Phase 7).
--
--   passes.qr_token_hash   sha256(qr_token) in hex: what gate phones keep instead of tokens
--   offline_pass_cache()   approved passes (fingerprints) and open visits, for the phone's cache
--   record_offline_scan()  sync of a scan made offline, by fingerprint, with its original time;
--                          if the pass changed meanwhile the visit is still recorded and an
--                          offline_conflict flag raised (the person is already inside)
--   record_scan()          unchanged behaviour; now a wrapper around private.do_record_scan.
--                          Online scans are never let through on conflict, whatever scanned_at says.

alter table public.passes
  add column qr_token_hash text generated always as (encode(extensions.digest(qr_token, 'sha256'), 'hex')) stored;
create unique index passes_qr_token_hash_idx on public.passes (qr_token_hash);
comment on column public.passes.qr_token_hash is 'sha256(qr_token), hex. Gate phones cache this, never the token.';

-- The fingerprint identifies a pass as well as the token does: keep it out of the audit log.
create or replace function private.audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  redacted constant text[] := array[
    'full_name', 'id_number', 'phone', 'email', 'fcm_token',
    'plate', 'vehicle_plate', 'description', 'host_name', 'purpose',
    'qr_token', 'status_token', 'storage_path',
    'contact_email', 'contact_phone', 'qr_token_hash'
  ];
  old_row jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  new_row jsonb := case when tg_op in ('UPDATE', 'INSERT') then to_jsonb(new) end;
  row_data jsonb := coalesce(new_row, old_row);
  details jsonb := '{}'::jsonb;
  col text;
begin
  if tg_op = 'UPDATE' then
    for col in select jsonb_object_keys(new_row) loop
      if new_row -> col is distinct from old_row -> col then
        details := details || jsonb_build_object(
          col,
          case when col = any (redacted) then '"redacted"'::jsonb
               else jsonb_build_object('old', old_row -> col, 'new', new_row -> col)
          end
        );
      end if;
    end loop;
    if details = '{}'::jsonb then
      return null; -- no-op update, nothing to record
    end if;
    details := jsonb_build_object('changed', details);
  else
    details := jsonb_build_object('row', row_data - redacted);
  end if;

  perform private.write_audit(lower(tg_op), tg_table_name, row_data ->> 'id', details);
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Shared scan logic (the former body of record_scan) with an explicit offline flag.
-- ---------------------------------------------------------------------------
create function private.do_record_scan(
  p_qr_token text,
  p_gate_id uuid,
  p_scanned_at timestamptz,
  p_client_event_id uuid,
  p_offline boolean
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
  v_offline boolean := p_offline or (p_scanned_at is not null and p_scanned_at < now() - interval '1 minute');
  v_conflict text;
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
    if p_offline then
      -- The phone was offline and let them through on its cached copy of the pass.
      -- They are inside: record the entry and flag it for review instead of refusing.
      insert into public.flags (type, pass_id, details)
      values ('offline_conflict', v_pass.id, jsonb_strip_nulls(jsonb_build_object(
        'result', v_result,
        'gate_id', p_gate_id,
        'scanned_at', v_at,
        'scanned_by', v_actor,
        'client_event_id', p_client_event_id
      )));
      v_conflict := v_result;
    else
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
  end if;

  -- 4. Entry, with the plate from the pass.
  select plate into v_plate from public.vehicles where id = v_pass.vehicle_id;
  insert into public.visits (
    pass_id, person_id, gate_id, vehicle_plate, entry_at, entry_by, client_entry_id, recorded_offline
  ) values (
    v_pass.id, v_pass.person_id, p_gate_id, v_plate, v_at, v_actor, p_client_event_id, v_offline
  )
  returning * into v_visit;
  return private.scan_payload('entry_recorded', v_pass.id, v_visit)
    || case when v_conflict is null then '{}'::jsonb else jsonb_build_object('conflict', v_conflict) end;
end;
$$;

revoke execute on function private.do_record_scan(text, uuid, timestamptz, uuid, boolean) from public, anon, authenticated;

create or replace function public.record_scan(
  p_qr_token text,
  p_gate_id uuid,
  p_scanned_at timestamptz default null,
  p_client_event_id uuid default null
)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select private.do_record_scan(p_qr_token, p_gate_id, p_scanned_at, p_client_event_id, false);
$$;

-- ---------------------------------------------------------------------------
-- Sync of an offline scan. The phone sends the fingerprint it matched in its cache.
-- ---------------------------------------------------------------------------
create function public.record_offline_scan(
  p_token_hash text,
  p_gate_id uuid,
  p_scanned_at timestamptz,
  p_client_event_id uuid
)
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
  if p_client_event_id is null or p_scanned_at is null then
    raise exception 'event_id_and_time_required' using errcode = '22023';
  end if;
  select qr_token into v_token from public.passes where qr_token_hash = lower(p_token_hash);
  if v_token is null then
    return jsonb_build_object('result', 'invalid');
  end if;
  return private.do_record_scan(v_token, p_gate_id, p_scanned_at, p_client_event_id, true);
end;
$$;

comment on function public.record_offline_scan is
  'Sync a scan made offline (by token fingerprint, original time, event id). Operators only.';

-- ---------------------------------------------------------------------------
-- What a gate phone may keep for offline scanning: approved passes valid now or
-- starting within a week (fingerprints, never tokens), and who is on site.
-- ---------------------------------------------------------------------------
create function public.offline_pass_cache()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.has_role('guard') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'generated_at', now(),
    'passes', coalesce((
      select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'token_hash', pa.qr_token_hash,
        'pass_id', pa.id,
        'full_name', pe.full_name,
        'pass_type', pa.type,
        'plate', ve.plate,
        'valid_from', pa.valid_from,
        'valid_until', pa.valid_until
      )))
      from public.passes pa
      join public.people pe on pe.id = pa.person_id
      left join public.vehicles ve on ve.id = pa.vehicle_id
      where pa.status = 'approved'
        and pa.valid_until > now()
        and pa.valid_from < now() + interval '7 days'
    ), '[]'::jsonb),
    'open_visits', coalesce((
      select jsonb_agg(jsonb_build_object('pass_id', v.pass_id, 'visit_id', v.id, 'entry_at', v.entry_at))
      from public.visits v
      where v.exit_at is null
    ), '[]'::jsonb)
  );
end;
$$;

comment on function public.offline_pass_cache is 'Approved pass fingerprints and open visits for offline scanning. Operators only.';

revoke execute on function public.record_offline_scan(text, uuid, timestamptz, uuid) from public, anon;
revoke execute on function public.offline_pass_cache() from public, anon;
grant execute on function public.record_offline_scan(text, uuid, timestamptz, uuid) to authenticated;
grant execute on function public.offline_pass_cache() to authenticated;
