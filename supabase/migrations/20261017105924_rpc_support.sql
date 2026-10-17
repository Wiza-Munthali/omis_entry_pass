-- OMIS Entry — shared pieces for the core RPCs (docs/SPEC.md → Core flows and server logic).

-- Offline-queued gate requests (Phase 7) carry a device-generated id so a retried
-- sync never creates a second request.
alter table public.passes add column client_request_id uuid unique;
comment on column public.passes.client_request_id is 'Device-generated id for gate requests; makes offline retries idempotent.';

-- record_scan looks up blocked-scan replays by client_event_id.
create index flags_client_event_idx on public.flags ((details ->> 'client_event_id'))
where details ? 'client_event_id';

-- ---------------------------------------------------------------------------
-- Local time: all times are stored in UTC and the site runs on Africa/Blantyre (CAT).
-- ---------------------------------------------------------------------------
create function private.local_today()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'Africa/Blantyre')::date;
$$;

-- Midnight at the start of a local date, as a timestamptz.
create function private.local_midnight(d date)
returns timestamptz
language sql
immutable
set search_path = ''
as $$
  select d::timestamp at time zone 'Africa/Blantyre';
$$;

-- ID numbers are matched case- and space-insensitively ("mw 123" = "MW123").
create function private.normalize_id_number(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(upper(regexp_replace(p, '\s+', '', 'g')), '');
$$;

-- Trimmed text, or null when blank.
create function private.clean(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(btrim(p), '');
$$;

-- Find or create a vehicle for a person; returns null when no plate is given.
create function private.upsert_vehicle(p_person_id uuid, p_plate text)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_plate text := private.normalize_plate(p_plate);
  v_id uuid;
begin
  if v_plate is null then
    return null;
  end if;
  if v_plate !~ '^[A-Z0-9]+$' then
    raise exception 'invalid_plate' using errcode = '22023';
  end if;

  insert into public.vehicles (person_id, plate)
  values (p_person_id, v_plate)
  on conflict (person_id, plate) do update set plate = excluded.plate
  returning id into v_id;
  return v_id;
end;
$$;
