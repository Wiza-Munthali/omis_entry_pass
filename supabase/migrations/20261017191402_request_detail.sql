-- OMIS Entry — everything the request detail screen (R3) shows, in one call.
-- Receptionists cannot read other operators' profiles, so the names of who
-- registered and who decided the request come from here.

create function public.request_detail(p_pass_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v jsonb;
begin
  if not private.has_role('receptionist') then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  select jsonb_strip_nulls(jsonb_build_object(
    'pass_id', pa.id,
    'status', pa.status,
    'pass_type', pa.type,
    'source', pa.source,
    'host_name', pa.host_name,
    'purpose', pa.purpose,
    'valid_from', pa.valid_from,
    'valid_until', pa.valid_until,
    'requested_at', pa.created_at,
    'escalated_at', pa.escalated_at,
    'decided_at', pa.decided_at,
    'reject_reason', pa.reject_reason,
    'full_name', pe.full_name,
    'id_number', pe.id_number,
    'phone', coalesce(pa.contact_phone, pe.phone),
    'email', coalesce(pa.contact_email, pe.email),
    'plate', ve.plate,
    'requested_by_name', rq.full_name,
    'decided_by_name', dc.full_name,
    -- Photo paths only where the caller may view them (same rule as the storage policy).
    'photo_paths', (
      select jsonb_agg(ph.storage_path order by ph.created_at)
      from public.id_photos ph
      where ph.pass_id = pa.id
        and (private.has_role('admin') or private.is_deciding(pa.id))
    )
  ))
  into v
  from public.passes pa
  join public.people pe on pe.id = pa.person_id
  left join public.vehicles ve on ve.id = pa.vehicle_id
  left join public.profiles rq on rq.id = pa.requested_by
  left join public.profiles dc on dc.id = pa.decided_by
  where pa.id = p_pass_id and pa.type in ('day', 'week');

  if v is null then
    raise exception 'request_not_found' using errcode = '22023';
  end if;
  return v;
end;
$$;

comment on function public.request_detail is 'Visitor request with names of who registered and decided it. Receptionists and admins.';

revoke execute on function public.request_detail(uuid) from public, anon;
grant execute on function public.request_detail(uuid) to authenticated;
