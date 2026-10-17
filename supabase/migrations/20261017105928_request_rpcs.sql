-- OMIS Entry — passes and requests (docs/SPEC.md → Core flows 1, 3 and 4).
--
--   register_staff_pass(full_name, id_number, plate)       staff, after email verification
--   create_gate_request(...)                                guard registers a visitor at the gate
--   decide_request(pass_id, decision, reason)               receptionist approves or rejects
--
-- Errors: 42501 not allowed, 22023 invalid input (message names the field or problem),
-- P0001 business rule (message is a stable key such as 'pass_revoked').

-- ---------------------------------------------------------------------------
-- 1. Staff pass
-- ---------------------------------------------------------------------------
-- Saves the staff member's details and returns their pass, issuing one if needed.
-- Safe to call again: re-opening the portal returns the same pass, with any updated
-- name, ID number or vehicle. A revoked pass is never replaced automatically.
create function public.register_staff_pass(
  p_full_name text,
  p_id_number text,
  p_plate text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles;
  v_settings public.settings;
  v_name text := private.clean(p_full_name);
  v_id_number text := private.normalize_id_number(p_id_number);
  v_person_id uuid;
  v_vehicle_id uuid;
  v_pass public.passes;
begin
  select * into v_profile from public.profiles where id = v_uid and is_active;
  if not found then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select * into v_settings from public.settings;
  if lower(split_part(v_profile.email, '@', 2)) <> all (
    select lower(d) from unnest(v_settings.allowed_email_domains) d
  ) then
    raise exception 'email_domain_not_allowed' using errcode = '42501';
  end if;

  if v_name is null then
    raise exception 'full_name_required' using errcode = '22023';
  end if;
  if v_id_number is null then
    raise exception 'id_number_required' using errcode = '22023';
  end if;

  -- An ID number already on someone else's record is never taken over: linking it
  -- would show this account that person's passes. Reception resolves it.
  if exists (
    select 1 from public.people
    where id_number = v_id_number and profile_id is distinct from v_uid
  ) then
    raise exception 'id_number_in_use' using errcode = 'P0001';
  end if;

  insert into public.people (profile_id, full_name, id_number, email)
  values (v_uid, v_name, v_id_number, v_profile.email)
  on conflict (profile_id) do update
    set full_name = excluded.full_name,
        id_number = excluded.id_number,
        email = excluded.email
  returning id into v_person_id;

  update public.profiles set full_name = v_name where id = v_uid;

  v_vehicle_id := private.upsert_vehicle(v_person_id, p_plate);

  select * into v_pass
  from public.passes
  where person_id = v_person_id and type = 'staff'
  order by created_at desc
  limit 1
  for update;

  if found and v_pass.status = 'revoked' then
    raise exception 'pass_revoked' using errcode = 'P0001';
  end if;

  if found and v_pass.status = 'approved' and v_pass.valid_until > now() then
    update public.passes set vehicle_id = v_vehicle_id where id = v_pass.id
    returning * into v_pass;
  else
    insert into public.passes (person_id, vehicle_id, type, status, valid_from, valid_until, source, decided_at)
    values (v_person_id, v_vehicle_id, 'staff', 'approved', now(),
            now() + make_interval(days => v_settings.staff_pass_days), 'web', now())
    returning * into v_pass;
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'pass_id', v_pass.id,
    'qr_token', v_pass.qr_token,
    'status', v_pass.status,
    'valid_from', v_pass.valid_from,
    'valid_until', v_pass.valid_until,
    'plate', private.normalize_plate(p_plate)
  ));
end;
$$;

comment on function public.register_staff_pass is
  'Staff: save name, ID number and optional plate; returns the approved staff pass and its QR token.';

-- ---------------------------------------------------------------------------
-- 3. Guard-created request (visitor without email)
-- ---------------------------------------------------------------------------
-- Returning visitors are matched on ID number. p_client_request_id makes offline
-- retries idempotent: the same id returns the request created the first time.
create function public.create_gate_request(
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
      return jsonb_build_object('pass_id', v_pass.id, 'status', v_pass.status,
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

  return jsonb_build_object('pass_id', v_pass.id, 'status', v_pass.status,
                            'valid_from', v_pass.valid_from, 'valid_until', v_pass.valid_until);
end;
$$;

comment on function public.create_gate_request is
  'Guard: register a visitor at the gate as a pending day or week request. Operators only.';

-- ---------------------------------------------------------------------------
-- 4. Approval
-- ---------------------------------------------------------------------------
-- First decision wins: a request that is no longer pending is not changed and the
-- caller gets result 'already_decided' with who decided it, so the app can show
-- "Already decided by someone else".
create function public.decide_request(
  p_pass_id uuid,
  p_decision text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pass public.passes;
  v_reason text := private.clean(p_reason);
  v_status public.pass_status;
begin
  if not private.has_role('receptionist') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  v_status := case p_decision when 'approve' then 'approved' when 'reject' then 'rejected' end;
  if v_status is null then
    raise exception 'decision_must_be_approve_or_reject' using errcode = '22023';
  end if;

  select * into v_pass from public.passes where id = p_pass_id for update;
  if not found then
    raise exception 'request_not_found' using errcode = '22023';
  end if;

  if v_pass.status <> 'pending' then
    return jsonb_strip_nulls(jsonb_build_object(
      'result', 'already_decided',
      'pass_id', v_pass.id,
      'status', v_pass.status,
      'decided_by', v_pass.decided_by,
      'decided_by_name', (select full_name from public.profiles where id = v_pass.decided_by),
      'decided_at', v_pass.decided_at
    ));
  end if;

  if v_status = 'rejected' and v_reason is null then
    raise exception 'reason_required' using errcode = '22023';
  end if;
  if v_status = 'approved' and v_pass.valid_until <= now() then
    raise exception 'request_expired' using errcode = 'P0001';
  end if;

  update public.passes
  set status = v_status,
      decided_by = auth.uid(),
      decided_at = now(),
      reject_reason = case when v_status = 'rejected' then v_reason end
  where id = v_pass.id
  returning * into v_pass;

  perform private.write_audit('decide_request', 'passes', v_pass.id::text,
                              jsonb_strip_nulls(jsonb_build_object('decision', v_status, 'reason', v_reason)));

  return jsonb_strip_nulls(jsonb_build_object(
    'result', v_status,
    'pass_id', v_pass.id,
    'status', v_pass.status,
    'decided_by', v_pass.decided_by,
    'decided_at', v_pass.decided_at
  ));
end;
$$;

comment on function public.decide_request is
  'Receptionist or admin: approve or reject a pending request. First decision wins.';

revoke execute on function public.register_staff_pass(text, text, text) from public, anon;
revoke execute on function public.create_gate_request(text, text, public.pass_type, text, text, text, text, date, uuid) from public, anon;
revoke execute on function public.decide_request(uuid, text, text) from public, anon;
grant execute on function public.register_staff_pass(text, text, text) to authenticated;
grant execute on function public.create_gate_request(text, text, public.pass_type, text, text, text, text, date, uuid) to authenticated;
grant execute on function public.decide_request(uuid, text, text) to authenticated;
