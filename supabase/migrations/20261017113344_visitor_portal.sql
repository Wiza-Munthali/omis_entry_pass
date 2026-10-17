-- OMIS Entry — visitor portal (docs/SPEC.md → Core flows → 2. Visitor self-service request).
--
--   submit_visitor_request(...)    called only by the submit-visitor-request Edge Function
--                                  (service role); rate-limited by IP and phone, 5 per hour
--   get_request_status(token)      what the public status page /r/{token} may show
--   on decision                    Realtime broadcast to the status page, and an email to
--                                  the visitor through the notify-visitor Edge Function

create extension if not exists pg_net with schema extensions;

-- Contact details given with a web request. They belong to the request, not the person:
-- web input is unverified, so it never overwrites an existing person's record, and the
-- decision email goes to the address typed on this request.
alter table public.passes
  add column contact_email text,
  add column contact_phone text;
comment on column public.passes.contact_email is 'Email given with a web request; where the decision email is sent.';
comment on column public.passes.contact_phone is 'Phone given with a web request.';

-- ---------------------------------------------------------------------------
-- Rate limiting: successful web submissions per IP (hashed) and per phone.
-- ---------------------------------------------------------------------------
create table private.request_attempts (
  id bigint generated always as identity primary key,
  ip_hash text,
  phone text not null,
  created_at timestamptz not null default now()
);
create index request_attempts_ip_idx on private.request_attempts (ip_hash, created_at);
create index request_attempts_phone_idx on private.request_attempts (phone, created_at);
revoke all on private.request_attempts from public, anon, authenticated;

-- "+265 991 234 567", "0991234567" and "265991234567" are the same number.
create function private.normalize_phone(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  with digits as (select regexp_replace(coalesce(p, ''), '\D', '', 'g') as d)
  select case
    when d = '' then null
    when d ~ '^0\d{9}$' then '+265' || substr(d, 2)
    when d ~ '^265\d{9}$' then '+' || d
    else '+' || d
  end
  from digits;
$$;

-- ---------------------------------------------------------------------------
-- Submit (service role only)
-- ---------------------------------------------------------------------------
create function public.submit_visitor_request(
  p_full_name text,
  p_phone text,
  p_email text,
  p_id_number text,
  p_host_name text,
  p_purpose text,
  p_pass_type public.pass_type,
  p_start_date date default null,
  p_plate text default null,
  p_ip text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_limit constant int := 5;
  v_today date := private.local_today();
  v_start date := coalesce(p_start_date, v_today);
  v_name text := private.clean(p_full_name);
  v_phone text := private.normalize_phone(p_phone);
  v_email text := lower(private.clean(p_email));
  v_id_number text := private.normalize_id_number(p_id_number);
  v_host text := private.clean(p_host_name);
  v_purpose text := private.clean(p_purpose);
  v_ip_hash text := case when private.clean(p_ip) is not null
                      then encode(extensions.digest(btrim(p_ip), 'sha256'), 'hex') end;
  v_week_days int;
  v_person_id uuid;
  v_vehicle_id uuid;
  v_pass public.passes;
begin
  if v_name is null then raise exception 'full_name_required' using errcode = '22023'; end if;
  if v_phone is null or length(v_phone) < 8 then raise exception 'phone_required' using errcode = '22023'; end if;
  if v_email is null or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'email_required' using errcode = '22023';
  end if;
  if v_id_number is null then raise exception 'id_number_required' using errcode = '22023'; end if;
  if v_host is null then raise exception 'host_name_required' using errcode = '22023'; end if;
  if v_purpose is null or v_purpose not in ('meeting', 'delivery', 'contractor', 'interview', 'other') then
    raise exception 'purpose_invalid' using errcode = '22023';
  end if;
  if p_pass_type is null or p_pass_type not in ('day', 'week') then
    raise exception 'pass_type_must_be_day_or_week' using errcode = '22023';
  end if;
  if v_start < v_today or v_start > v_today + 14 then
    raise exception 'start_date_out_of_range' using errcode = '22023';
  end if;

  -- Serialise submissions per phone so two parallel requests cannot both slip under the limit.
  perform pg_advisory_xact_lock(hashtext('visitor_request:' || v_phone));
  if v_ip_hash is not null then
    perform pg_advisory_xact_lock(hashtext('visitor_request_ip:' || v_ip_hash));
  end if;

  if (select count(*) from private.request_attempts
      where phone = v_phone and created_at > now() - interval '1 hour') >= c_limit
     or (v_ip_hash is not null and (select count(*) from private.request_attempts
      where ip_hash = v_ip_hash and created_at > now() - interval '1 hour') >= c_limit) then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;

  delete from private.request_attempts where created_at < now() - interval '1 day';
  insert into private.request_attempts (ip_hash, phone) values (v_ip_hash, v_phone);

  -- Returning visitors match on ID number; their stored details are only filled in, never replaced.
  insert into public.people (full_name, id_number, phone, email)
  values (v_name, v_id_number, v_phone, v_email)
  on conflict (id_number) do update
    set phone = coalesce(people.phone, excluded.phone),
        email = coalesce(people.email, excluded.email)
  returning id into v_person_id;

  v_vehicle_id := private.upsert_vehicle(v_person_id, p_plate);

  select week_pass_days into v_week_days from public.settings;

  insert into public.passes (
    person_id, vehicle_id, type, status, valid_from, valid_until,
    host_name, purpose, source, contact_email, contact_phone
  ) values (
    v_person_id, v_vehicle_id, p_pass_type, 'pending',
    private.local_midnight(v_start),
    case p_pass_type
      when 'day' then private.local_midnight(v_start + 1)
      else private.local_midnight(v_start) + make_interval(days => v_week_days)
    end,
    v_host, v_purpose, 'web', v_email, v_phone
  )
  returning * into v_pass;

  return jsonb_build_object('pass_id', v_pass.id, 'status_token', v_pass.status_token);
end;
$$;

comment on function public.submit_visitor_request is
  'Visitor self-service request. Service role only (submit-visitor-request Edge Function).';

revoke execute on function public.submit_visitor_request(text, text, text, text, text, text, public.pass_type, date, text, text)
  from public, anon, authenticated;
grant execute on function public.submit_visitor_request(text, text, text, text, text, text, public.pass_type, date, text, text)
  to service_role;

-- ---------------------------------------------------------------------------
-- Status page: anyone holding the secret status link sees this request only.
-- No ID number, phone or email; the QR only while the pass can be used.
-- ---------------------------------------------------------------------------
create function public.get_request_status(p_status_token text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with r as (
    select
      pa.*,
      pe.full_name,
      ve.plate,
      case
        when pa.status = 'approved' and pa.valid_until <= now() then 'expired'
        else pa.status::text
      end as shown_status
    from public.passes pa
    join public.people pe on pe.id = pa.person_id
    left join public.vehicles ve on ve.id = pa.vehicle_id
    where pa.status_token = p_status_token
      and pa.type in ('day', 'week')
  )
  select jsonb_strip_nulls(jsonb_build_object(
    'status', r.shown_status,
    'full_name', r.full_name,
    'pass_type', r.type,
    'host_name', r.host_name,
    'purpose', r.purpose,
    'plate', r.plate,
    'valid_from', r.valid_from,
    'valid_until', r.valid_until,
    'requested_at', r.created_at,
    'decided_at', r.decided_at,
    'reject_reason', case when r.status = 'rejected' then r.reject_reason end,
    'qr_token', case when r.shown_status = 'approved' then r.qr_token end
  ))
  from r;
$$;

comment on function public.get_request_status is 'Public status page for /r/{status_token}.';

revoke execute on function public.get_request_status(text) from public;
grant execute on function public.get_request_status(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- On every status change of a visitor request: tell the status page (Realtime
-- broadcast on the public topic request:{status_token}; the token is the secret).
-- ---------------------------------------------------------------------------
create function private.broadcast_request_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(
    jsonb_build_object('status', new.status),
    'status_changed',
    'request:' || new.status_token,
    false
  );
  return null;
end;
$$;

create trigger passes_broadcast_status
after update of status on public.passes
for each row
when (old.status is distinct from new.status and new.type in ('day', 'week'))
execute function private.broadcast_request_status();

-- ---------------------------------------------------------------------------
-- Decision email: a web request that was pending and is now approved or rejected
-- triggers the notify-visitor Edge Function. pg_net sends after commit, so a
-- rolled-back decision sends nothing. The function URL and a shared secret live in
-- Vault ('functions_url', 'internal_hook_secret'); without them no email is sent
-- and the decision still stands.
-- ---------------------------------------------------------------------------
create function private.call_edge_function(p_name text, p_body jsonb)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_secret text;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'functions_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'internal_hook_secret';
  if v_url is null or v_secret is null then
    raise warning 'Edge Function % not called: functions_url or internal_hook_secret missing from Vault', p_name;
    return null;
  end if;

  return net.http_post(
    url := rtrim(v_url, '/') || '/' || p_name,
    body := p_body,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-internal-secret', v_secret),
    timeout_milliseconds := 10000
  );
end;
$$;

revoke execute on function private.call_edge_function(text, jsonb) from public, anon, authenticated;

create function private.notify_visitor_of_decision()
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

create trigger passes_notify_visitor
after update of status on public.passes
for each row
when (
  old.status = 'pending'
  and new.status in ('approved', 'rejected')
  and new.source = 'web'
  and new.contact_email is not null
)
execute function private.notify_visitor_of_decision();

-- Personal contact fields stay out of the audit log, like the person fields.
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
    'contact_email', 'contact_phone'
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
