-- OMIS Entry — core schema (docs/SPEC.md → Data model).
-- RLS, grants and helper functions live in the next migration; this file is
-- types, tables, constraints and indexes only.

create schema if not exists private;
comment on schema private is 'Internal helpers. Not exposed through the Data API.';

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.user_role as enum ('admin', 'receptionist', 'guard', 'staff');
create type public.pass_type as enum ('staff', 'day', 'week');
create type public.pass_status as enum ('pending', 'approved', 'rejected', 'revoked', 'expired');
create type public.request_source as enum ('web', 'gate');
create type public.flag_type as enum (
  'exit_without_entry',
  'double_entry',
  'auto_closed',
  'scan_invalid_pass',
  'approval_escalated',
  'offline_conflict'
);

-- ---------------------------------------------------------------------------
-- Helpers used as column defaults
-- ---------------------------------------------------------------------------

-- Random URL-safe token: n random bytes, base64url, no padding.
create function private.gen_token(n_bytes int)
returns text
language sql
volatile
set search_path = ''
as $$
  select translate(encode(extensions.gen_random_bytes(n_bytes), 'base64'), E'+/=\n', '-_');
$$;

-- Plates are stored uppercase with no spaces ("bt 4521" → "BT4521").
create function private.normalize_plate(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(upper(regexp_replace(p, '\s+', '', 'g')), '');
$$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role public.user_role not null default 'staff',
  full_name text,
  email text not null,
  phone text,
  fcm_token text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
comment on table public.profiles is 'Operators (admin, receptionist, guard) and staff. One row per auth user.';

create table public.people (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid unique references public.profiles (id) on delete set null,
  full_name text not null,
  id_number text unique,
  phone text,
  email text,
  created_at timestamptz not null default now()
);
comment on table public.people is 'Anyone who holds a pass. Visitors have no profile; returning visitors match on id_number.';

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people (id) on delete cascade,
  plate text not null check (plate ~ '^[A-Z0-9]+$'),
  description text,
  created_at timestamptz not null default now(),
  unique (person_id, plate)
);
comment on column public.vehicles.plate is 'Uppercase, no spaces. Normalised by trigger.';

create table public.gates (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.passes (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.people (id),
  vehicle_id uuid references public.vehicles (id) on delete set null,
  type public.pass_type not null,
  status public.pass_status not null default 'pending',
  qr_token text not null unique default private.gen_token(32),
  status_token text not null unique default private.gen_token(24),
  valid_from timestamptz not null,
  valid_until timestamptz not null,
  host_name text,
  purpose text,
  source public.request_source not null default 'web',
  requested_by uuid references public.profiles (id) on delete set null,
  decided_by uuid references public.profiles (id) on delete set null,
  decided_at timestamptz,
  reject_reason text,
  escalated_at timestamptz,
  created_at timestamptz not null default now(),
  check (valid_until > valid_from),
  check (status <> 'rejected' or reject_reason is not null)
);
comment on column public.passes.qr_token is '32 random bytes, base64url. Shown as the QR code.';
comment on column public.passes.status_token is 'Secret for the visitor status link /r/{status_token}.';

create table public.visits (
  id uuid primary key default gen_random_uuid(),
  pass_id uuid not null references public.passes (id),
  person_id uuid not null references public.people (id),
  gate_id uuid not null references public.gates (id),
  vehicle_plate text,
  entry_at timestamptz not null,
  entry_by uuid references public.profiles (id) on delete set null,
  exit_at timestamptz,
  exit_by uuid references public.profiles (id) on delete set null,
  auto_closed boolean not null default false,
  client_entry_id uuid unique,
  client_exit_id uuid unique,
  recorded_offline boolean not null default false,
  created_at timestamptz not null default now(),
  check (exit_at is null or exit_at >= entry_at)
);
comment on table public.visits is 'One row per stay. Open visit = exit_at is null. Written only by RPCs.';

create table public.id_photos (
  id uuid primary key default gen_random_uuid(),
  pass_id uuid not null references public.passes (id) on delete cascade,
  storage_path text not null unique,
  uploaded_by uuid default auth.uid() references public.profiles (id) on delete set null,
  delete_after timestamptz not null,
  created_at timestamptz not null default now()
);
comment on column public.id_photos.storage_path is 'Object path in the private id-photos bucket: {pass_id}/{uuid}.jpg';

create table public.flags (
  id uuid primary key default gen_random_uuid(),
  type public.flag_type not null,
  pass_id uuid references public.passes (id) on delete set null,
  visit_id uuid references public.visits (id) on delete set null,
  details jsonb not null default '{}'::jsonb,
  resolved_by uuid references public.profiles (id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.settings (
  id boolean primary key default true check (id),
  org_name text not null default 'GHII',
  allowed_email_domains text[] not null default '{}',
  approval_timeout_minutes int not null default 5 check (approval_timeout_minutes > 0),
  auto_close_time time not null default '23:59',
  id_photo_retention_days int not null default 30 check (id_photo_retention_days > 0),
  staff_pass_days int not null default 365 check (staff_pass_days > 0),
  week_pass_days int not null default 7 check (week_pass_days > 0)
);
comment on table public.settings is 'Single row (id = true). Times are local to Africa/Blantyre (CAT).';
insert into public.settings default values;

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid,
  action text not null,
  target_table text not null,
  target_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
comment on table public.audit_log is 'Append-only. Written by triggers and RPCs; never by clients.';

-- ---------------------------------------------------------------------------
-- Indexes (qr_token, status_token and id_number are covered by unique constraints)
-- ---------------------------------------------------------------------------
create index passes_status_valid_until_idx on public.passes (status, valid_until);
create index passes_person_id_idx on public.passes (person_id);
-- At most one open visit per pass; also serves "find the open visit" lookups.
create unique index visits_open_pass_idx on public.visits (pass_id) where exit_at is null;
create index visits_entry_at_idx on public.visits (entry_at desc);
create index vehicles_plate_idx on public.vehicles (plate);
create index id_photos_delete_after_idx on public.id_photos (delete_after);
create index flags_unresolved_idx on public.flags (created_at) where resolved_at is null;
create index audit_log_target_idx on public.audit_log (target_table, target_id);

-- ---------------------------------------------------------------------------
-- Normalisation triggers
-- ---------------------------------------------------------------------------
create function private.normalize_vehicle_plate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.plate := private.normalize_plate(new.plate);
  return new;
end;
$$;

create trigger vehicles_normalize_plate
before insert or update of plate on public.vehicles
for each row execute function private.normalize_vehicle_plate();

create function private.normalize_visit_plate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.vehicle_plate := private.normalize_plate(new.vehicle_plate);
  return new;
end;
$$;

create trigger visits_normalize_plate
before insert or update of vehicle_plate on public.visits
for each row execute function private.normalize_visit_plate();

-- id_photos.delete_after defaults to now() + settings.id_photo_retention_days.
create function private.set_id_photo_delete_after()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.delete_after is null then
    select now() + make_interval(days => s.id_photo_retention_days)
      into new.delete_after
      from public.settings s;
  end if;
  return new;
end;
$$;

create trigger id_photos_set_delete_after
before insert on public.id_photos
for each row execute function private.set_id_photo_delete_after();
