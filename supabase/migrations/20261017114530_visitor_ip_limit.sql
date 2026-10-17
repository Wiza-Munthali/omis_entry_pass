-- OMIS Entry — visitor request limits: 5 per hour per phone (unchanged), 30 per hour per IP.
--
-- Mobile networks put many phones behind one public IP (carrier-grade NAT), and visitors
-- at the gate poster may share guest Wi-Fi, so 5 per IP would turn away real visitors.
-- The phone limit still stops one person flooding reception. Only the constants and
-- the check below differ from 20261017113344_visitor_portal.sql.

create or replace function public.submit_visitor_request(
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
  c_phone_limit constant int := 5;   -- per phone per hour
  c_ip_limit constant int := 30;     -- per network per hour: many visitors share one IP
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
      where phone = v_phone and created_at > now() - interval '1 hour') >= c_phone_limit
     or (v_ip_hash is not null and (select count(*) from private.request_attempts
      where ip_hash = v_ip_hash and created_at > now() - interval '1 hour') >= c_ip_limit) then
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
