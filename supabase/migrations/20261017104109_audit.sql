-- OMIS Entry — audit log triggers (docs/SPEC.md → audit_log).
--
-- Every insert, update and delete on the business tables writes one audit_log row with
-- the acting user (auth.uid(), null for server jobs). Personal fields and secrets are
-- never copied into the log: they appear as "redacted" so the log shows that they
-- changed without keeping a second copy (purge jobs only need to clean the source rows).

-- RPCs also call this directly for named actions (e.g. 'decide_request').
create function private.write_audit(
  p_action text,
  p_target_table text,
  p_target_id text,
  p_details jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.audit_log (actor_id, action, target_table, target_id, details)
  values (auth.uid(), p_action, p_target_table, p_target_id, coalesce(p_details, '{}'::jsonb));
$$;

create function private.audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  redacted constant text[] := array[
    'full_name', 'id_number', 'phone', 'email', 'fcm_token',
    'plate', 'vehicle_plate', 'description', 'host_name', 'purpose',
    'qr_token', 'status_token', 'storage_path'
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

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'people', 'vehicles', 'passes', 'visits',
    'gates', 'id_photos', 'flags', 'settings'
  ] loop
    execute format(
      'create trigger audit_%1$s after insert or update or delete on public.%1$I
       for each row execute function private.audit_row()',
      t
    );
  end loop;
end;
$$;
