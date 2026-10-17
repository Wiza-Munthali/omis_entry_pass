-- OMIS Entry — privacy notice (Phase 9).
--
-- The public /privacy page states what is kept and for how long, using the live values:
-- the ID photo retention setting, the request purge period and the rate-limit window.
-- Admins can name who people should contact about their data (settings.privacy_contact).

alter table public.settings
  add column privacy_contact text check (char_length(privacy_contact) <= 200);
comment on column public.settings.privacy_contact is
  'Who to contact about personal data (an email address, office or person). Shown on /privacy.';

grant update (privacy_contact) on public.settings to authenticated;

-- One place for the request purge period, used by the job and the notice.
create function private.request_retention_days()
returns int
language sql
immutable
set search_path = ''
as $$ select 90 $$;

create or replace function private.purge_old_requests()
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
      and created_at < now() - private.request_retention_days() * interval '1 day'
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
        and not (pa.created_at < now() - private.request_retention_days() * interval '1 day' and (pa.status = 'rejected' or pa.decided_at is null))
    );

  update public.people pe
  set full_name = 'Removed', id_number = null, phone = null, email = null
  where pe.profile_id is null
    and pe.full_name <> 'Removed'
    and exists (select 1 from public.passes pa where pa.person_id = pe.id)
    and not exists (
      select 1 from public.passes pa
      where pa.person_id = pe.id
        and not (pa.created_at < now() - private.request_retention_days() * interval '1 day' and (pa.status = 'rejected' or pa.decided_at is null))
    );

  return v_count;
end;
$$;

create function public.privacy_notice()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'org_name', s.org_name,
    'privacy_contact', s.privacy_contact,
    'id_photo_retention_days', s.id_photo_retention_days,
    'request_retention_days', private.request_retention_days(),
    'rate_limit_retention_hours', 24
  )
  from public.settings s;
$$;

comment on function public.privacy_notice is 'Facts for the public privacy notice: who runs the system, the contact, and retention periods.';

revoke execute on function public.privacy_notice() from public;
grant execute on function public.privacy_notice() to anon, authenticated;

-- Rate-limit records (hashed IP, phone) were only cleared when the next request came in;
-- clear them hourly so the notice's "kept for a day" always holds.
create function private.purge_request_attempts()
returns int
language sql
security definer
set search_path = ''
as $$
  with gone as (
    delete from private.request_attempts where created_at < now() - interval '1 day' returning 1
  )
  select count(*)::int from gone;
$$;

select cron.schedule('purge-request-attempts', '7 * * * *', 'select private.purge_request_attempts()');
