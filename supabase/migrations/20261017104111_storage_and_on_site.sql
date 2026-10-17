-- OMIS Entry — ID photo bucket and the on-site view.

-- ---------------------------------------------------------------------------
-- Private bucket for ID photos: id-photos/{pass_id}/{uuid}.jpg, JPEG, max 400 KB.
-- Same rules as the id_photos table: guards upload for their own pending gate
-- requests; receptionists read requests they are deciding; admins read all.
-- No client updates or deletes; the cleanup job uses the service role.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('id-photos', 'id-photos', false, 409600, array['image/jpeg']);

-- First path segment as a uuid, or null if it is not one.
create function private.pass_id_from_path(object_name text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
begin
  return (storage.foldername(object_name))[1]::uuid;
exception
  when invalid_text_representation then
    return null;
end;
$$;

create policy "id-photos: guards upload for own gate request"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'id-photos'
  and (select private.has_role('guard'))
  and private.can_attach_id_photo(private.pass_id_from_path(name))
);

create policy "id-photos: receptionists read deciding, admins read all"
on storage.objects for select to authenticated
using (
  bucket_id = 'id-photos'
  and (
    (select private.has_role('admin'))
    or (
      (select private.has_role('receptionist'))
      and private.is_deciding(private.pass_id_from_path(name))
    )
  )
);

-- ---------------------------------------------------------------------------
-- on_site: who is on site right now, for every operator (guards included).
-- Guards cannot read people or passes directly, so this view runs with the owner's
-- rights (security_invoker off) and filters itself with has_role('guard').
-- security_barrier stops caller-supplied predicates from running before that filter.
-- ---------------------------------------------------------------------------
create view public.on_site
with (security_invoker = false, security_barrier = true)
as
select
  v.id as visit_id,
  v.pass_id,
  v.person_id,
  p.full_name,
  pa.type as pass_type,
  v.vehicle_plate,
  v.gate_id,
  g.name as gate_name,
  v.entry_at,
  v.entry_by
from public.visits v
join public.people p on p.id = v.person_id
join public.passes pa on pa.id = v.pass_id
join public.gates g on g.id = v.gate_id
where v.exit_at is null
  and private.has_role('guard');

comment on view public.on_site is 'Open visits with names, readable by active operators only.';

revoke all on public.on_site from anon, authenticated;
grant select on public.on_site to authenticated;
